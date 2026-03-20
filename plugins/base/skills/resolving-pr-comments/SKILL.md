---
name: resolving-pr-comments
description: >-
  Resolve all unresolved review threads on the current PR. Use when the user
  wants to bulk-resolve PR comments after addressing feedback, mark threads as
  done, or close out review discussions. Also trigger on "resolve threads",
  "スレッド解決", "レビューコメント解決", "resolve all comments", "コメント全部解決して",
  "close review threads", or any request to mark review threads as resolved on
  a pull request. Even if the user simply says "resolve" in the context of a PR
  review workflow, this skill is likely what they need.
model: sonnet
allowed-tools: Bash(bash:*), Bash(gh:*), Read
context: fork
---

# Resolve PR Comments

Bulk-resolve all unresolved review threads on the current GitHub PR via the GraphQL API.

## Why This Exists

Manually clicking "Resolve conversation" on every thread in the GitHub UI is tedious after addressing a batch of review comments. This turns that into a single action.

## Before Running

Resolving threads signals to reviewers that their feedback has been addressed. If a reviewer disagrees, they have to unresolve the thread or leave a new comment — that creates friction and can feel dismissive. Only resolve threads when the underlying concerns have genuinely been handled.

Confirm with the user before proceeding. Show how many threads will be resolved and ask for a go-ahead. Don't skip this step — this is an action that directly affects the reviewer's workflow.

## Run the Script

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/resolve-pr-comments.sh"
```

Prerequisite: the current directory must be a git repo with an open PR on the current branch (`gh pr view` must succeed).

The script outputs the count of unresolved threads, the result for each resolution attempt, and a final summary.

## After Running

Report the summary to the user. If any threads failed to resolve, surface the error details — the user needs to know whether to retry or investigate.
