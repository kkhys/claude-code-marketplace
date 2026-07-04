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
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Read
---

# Fix Review Comments

Close the PR review feedback loop: read what reviewers asked for, implement the changes, verify nothing broke, and let them know what was done.

## PR Context

!`gh pr view --json number,title,url,state 2>/dev/null || echo "No open PR found for the current branch"`

## Phase 1: Understand the Feedback

Invoke the `reading-unresolved-pr-comments` skill. It fetches all unresolved threads via GraphQL and produces a structured fix plan.

Before jumping into code, review the plan carefully:

- What is each reviewer actually asking for? A comment like "rename this variable" often means "this name is misleading because it implies X when the value is Y." Catching the deeper intent avoids a second round of review.
- Are any threads marked `is_outdated`? The referenced lines may have shifted or been rewritten. Verify the current code state before planning a fix for these.
- Which fixes touch the same file or function? Group them so coordinated changes stay consistent.
- Which fixes are truly independent? Those can run in parallel later.

## Phase 2: Implement Fixes

Launch subagents for each fix task. The fix plan from Phase 1 determines execution strategy:

- Independent fixes (different files, no shared state) → launch in parallel
- Related fixes (same file, overlapping logic) → run sequentially to prevent conflicts
- Each subagent needs: the review comment, file path, line range, and the specific change to make

When a reviewer suggests an approach but leaves room for alternatives, make the call that best serves the codebase. Note the reasoning — it will go into the thread reply in Phase 4.

## Phase 3: Verify and Commit

Run the project's test suite and linter. Pushing broken code to a PR wastes the reviewer's time and erodes trust in the review process — catching failures at this stage is essential.

- If any check fails, fix the issues before proceeding
- Once all checks pass, invoke the `formatting-commit` skill to commit all fixes together
- Push with `git push --force-with-lease` (the branch has existing history, so a regular push will be rejected)

All fixes go in a single commit. Splitting them across multiple commits creates noise in the review thread and makes it harder for the reviewer to see the full picture of what changed.

## Phase 4: Close the Loop

Reviewers need to know their feedback was heard. A generic "修正しました" tells them nothing — they'd have to dig through the diff to verify each point. Specific replies save everyone's time.

For each unresolved thread, compose a reply that includes:
1. What was changed (specific enough that the reviewer can confirm without reading the diff)
2. A link to the commit for verification

Get the commit URL:

```bash
COMMIT_URL="$(gh api "repos/$(gh repo view --json nameWithOwner -q '.nameWithOwner')/commits/$(git rev-parse HEAD)" --jq '.html_url')"
```

Build a JSON payload and post all replies at once:

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

### Thread Resolution

Do not auto-resolve threads. Resolution is the reviewer's prerogative — they decide when the fix is satisfactory. If the user explicitly asks to resolve threads, invoke the `resolving-pr-comments` skill.
