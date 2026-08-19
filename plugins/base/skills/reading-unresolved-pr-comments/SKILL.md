---
name: reading-unresolved-pr-comments
description: >-
  Fetch and analyze unresolved PR review comments using a specialized GraphQL
  script that extracts thread-level data (thread IDs, resolution status,
  outdated flags, line ranges) not available through basic gh commands, then
  produce a fix plan.
when_to_use: >-
  MUST consult whenever the user wants to check review feedback, see what
  reviewers said, view unresolved threads, or prepare to address reviewer
  requests on a PR — "review comments", "レビューコメント", "unresolved
  threads", "レビュー指摘", "reviewer feedback", "PR feedback". Required
  first step of the fixing-review-comments workflow.
context: fork
agent: Explore
background: false
allowed-tools:
  - Bash(bash:*)
  - Bash(gh:*)
  - Read
---

# Read Unresolved PR Comments

Fetch unresolved review comments from the current PR and produce a fix plan that downstream skills can act on.

## PR Context

!`gh pr view --json number,title,url 2>/dev/null || echo "No open PR found for the current branch"`

## Fetch Comments

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/read-unresolved-pr-comments.sh"
```

`${CLAUDE_SKILL_DIR}` is this skill's directory; when the variable reaches you unexpanded, use the directory that holds this SKILL.md.

Prerequisite: the current branch must have an open PR (`gh pr view` must succeed).

The script returns JSON with PR metadata and all unresolved threads. Each thread includes `thread_id`, `path`, `line`, `start_line`, `is_outdated`, and the full comment history.

## Create Fix Plan

If no unresolved threads exist, report that to the user and stop.

Analyze each thread to understand what the reviewer is actually asking for. Often the surface-level comment ("rename this variable") reflects a deeper concern ("this name is misleading because it suggests X when the value is Y"). Capture both the specific ask and the underlying intent.

Structure the plan as follows:

1. Group comments that affect the same file or function — coordinated changes reduce conflicts and maintain consistency
2. Order groups by dependency (foundational changes first, dependent changes after)
3. For each fix item, include the file path, line, reviewer's concern (the "why"), and the concrete action to take
4. Mark `is_outdated` threads explicitly — the referenced code may have already changed, so verify the current state before planning a fix
5. Design each fix to be independently actionable, since `fixing-review-comments` may execute them in parallel via subagents

## Scope

This skill only reads and plans. It does not modify code, resolve threads, or push changes. The fix plan is a checkpoint for the user or the calling skill to review before any code is touched.
