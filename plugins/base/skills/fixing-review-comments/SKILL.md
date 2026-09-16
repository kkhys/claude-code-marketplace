---
name: fixing-review-comments
description: >-
  Address unresolved review comments on the current branch by orchestrating
  the full fix cycle: reading feedback, implementing changes, verifying,
  committing, and replying to reviewers.
when_to_use: >-
  Trigger whenever the user wants to fix PR review feedback, address reviewer
  comments, handle review points, or respond to code review —
  "レビューコメント直して", "fix the review comments", "address the feedback",
  "review 対応して", "レビュー指摘を修正". This is the primary skill for
  closing the PR review feedback loop.
argument-hint: "[PR URL or number, or a #discussion_r<id> thread URL]"
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
---

# Fix Review Comments

Close the PR review feedback loop: read what reviewers asked for, implement the changes, verify nothing broke, and let them know what was done.

## PR Context

!`gh pr view --json number,title,url,state 2>/dev/null || echo "No open PR found for the current branch"`

## Target

$ARGUMENTS

A PR URL or number, optionally narrowed to one thread (`#discussion_r<id>` — match it against the comment `url` fields in the fetched threads and handle only that one). Blank means the current branch's PR.

When the PR's head branch is not the one checked out, or the user is working elsewhere in this checkout (「worktreeで」), use a worktree so their tree stays untouched, and run every later step from that directory — the scripts resolve the PR from the current branch:

```bash
git fetch origin <head>
git worktree add .claude/worktrees/<head-slug> <head> 2>/dev/null \
  || git worktree add --track -b <head> .claude/worktrees/<head-slug> origin/<head>
```

## Phase 1: Understand the Feedback

Invoke `reading-unresolved-pr-comments`. It fetches every unresolved thread and returns a fix plan with the reviewer's underlying intent, outdated flags, and grouping.

Then check each item against the code before changing anything. A comment can be wrong, already addressed, or a judgment call:

- Wrong or already handled → no code change; the reply carries the evidence (the line that already does it, the reason the concern does not apply)
- A product or design decision → surface it with a suggested reply and wait

Only the remaining items go to Phase 2.

## Phase 2: Implement Fixes

Launch subagents for each fix task. The fix plan from Phase 1 determines execution strategy:

- Independent fixes (different files, no shared state) → launch in parallel
- Related fixes (same file, overlapping logic) → run sequentially to prevent conflicts
- Each subagent needs: the review comment, file path, line range, and the specific change to make

When a reviewer suggests an approach but leaves room for alternatives, make the call that best serves the codebase. Note the reasoning — it will go into the thread reply in Phase 4.

## Phase 3: Verify and Commit

Run the project's test suite and linter; fix what fails before going on. Then commit every fix of this round as one new commit via `formatting-commit` — never amend under review — and push with plain `git push`. One commit per round keeps the reviewer's per-round diff intact.

## Phase 4: Close the Loop

For each thread handled, reply with:
1. What was changed — specific enough that the reviewer can confirm without reading the diff — or, for a comment that needed no change, the evidence
2. A link to the commit, when there is one

Get the commit URL:

```bash
COMMIT_URL="$(gh api "repos/$(gh repo view --json nameWithOwner -q '.nameWithOwner')/commits/$(git rev-parse HEAD)" --jq '.html_url')"
```

Build a JSON payload and post all replies at once (`${CLAUDE_SKILL_DIR}` is this skill's directory; when the variable reaches you unexpanded, use the directory that holds this SKILL.md):

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/reply-to-review-threads.sh" /path/to/replies.json
```

Payload format:

```json
{
  "replies": [
    {
      "thread_id": "<thread ID from Phase 1>",
      "body": "<COMMIT_URL> で修正しました。[具体的な修正内容]"
    }
  ]
}
```

Write replies in Japanese. Be concise but specific — one sentence per reply that describes the actual change made.

### Attribution

The script prefixes every reply with `[from Claude Code]`, so write the body without it. Reviewers need to tell an agent's reply from the user's own — an unmarked reply reads as a personal commitment from the user. The same marker belongs on anything posted with plain `gh pr comment`, where nothing adds it for you.

### Thread Resolution

Do not auto-resolve threads. Resolution is the reviewer's prerogative — they decide when the fix is satisfactory. If the user explicitly asks to resolve threads, invoke the `resolving-pr-comments` skill.

One workflow overrides this: `babysitting-pr` resolves the threads it addressed, because its terminal condition is "no unresolved threads" and an addressed-but-open thread would keep it polling forever. That override belongs to that skill; on its own, this one leaves resolution alone.
