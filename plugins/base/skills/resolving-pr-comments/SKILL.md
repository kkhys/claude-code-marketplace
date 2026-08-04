---
name: resolving-pr-comments
description: >-
  Resolve review threads on the current PR via the GraphQL API — every
  unresolved thread after confirming with the user, or a specific list of
  thread IDs when a calling workflow supplies them.
when_to_use: >-
  Use when the user wants to bulk-resolve PR comments after addressing
  feedback, mark threads as done, or close out review discussions —
  "resolve threads", "スレッド解決", "レビューコメント解決",
  "resolve all comments", "コメント全部解決して", "close review threads".
  Even a bare "resolve" during a PR review workflow likely means this. Also
  used by `babysitting-pr` to resolve the specific threads it addressed.
allowed-tools:
  - Bash(bash:*)
  - Bash(gh:*)
  - Read
---

# Resolve PR Comments

Resolve review threads on the current GitHub PR via the GraphQL API — all unresolved ones, or a specific list.

## PR Context

!`gh pr view --json number,title,url 2>/dev/null || echo "No open PR found for the current branch"`

## Why This Exists

Manually clicking "Resolve conversation" on every thread in the GitHub UI is tedious after addressing a batch of review comments. This turns that into a single action.

## Before Running

Resolving threads signals to reviewers that their feedback has been addressed. If a reviewer disagrees, they have to unresolve the thread or leave a new comment — that creates friction and can feel dismissive. Only resolve threads when the underlying concerns have genuinely been handled.

Confirm with the user before proceeding. Show how many threads will be resolved and ask for a go-ahead. Don't skip this step — this is an action that directly affects the reviewer's workflow.

The exception is a caller that already knows exactly which threads it fixed and replied to (`babysitting-pr` runs this way). Resolving that explicit list is a bookkeeping step in a workflow the user already authorized, so it needs no separate confirmation.

## Run the Script

Every unresolved thread on the current branch's PR:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/resolve-pr-comments.sh"
```

Only specific threads — pass the thread IDs from `reading-unresolved-pr-comments`:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/resolve-pr-comments.sh" PRRT_kwDOAbc123 PRRT_kwDOAbc456
```

Prefer the explicit form whenever you know which threads you handled. A bulk resolve also closes threads that arrived while you were working, or ones you deliberately left open pending a decision.

Prerequisite for the bulk form: the current directory must be a git repo with an open PR on the current branch (`gh pr view` must succeed). The explicit form works from anywhere, since thread IDs are globally unique.

The script outputs the count of threads, the result for each resolution attempt, and a final summary.

## After Running

Report the summary to the user. If any threads failed to resolve, surface the error details — the user needs to know whether to retry or investigate.
