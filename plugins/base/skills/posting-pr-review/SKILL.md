---
name: posting-pr-review
description: Post review comments to a GitHub PR as a PENDING review. Use after completing code review (pr-review-toolkit:review-pr or similar) to submit structured feedback with severity indicators.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cat:*), Bash(mktemp:*), Bash(rm:*), Read
---

# Post PR Review Comments

Post structured review comments to a GitHub PR as a PENDING review. The user will manually submit the review after confirming on GitHub.

## Prerequisites

This skill requires review results from the current session. Acceptable sources:
- `pr-review-toolkit:review-pr` agent output
- `pr-review-toolkit:code-reviewer` agent output
- `pr-review-toolkit:silent-failure-hunter` agent output
- Any structured code review findings with file paths and line numbers

If no review data exists in the current session, prompt the user:
> セッション内にレビュー結果が見つかりません。先に `pr-review-toolkit:review-pr` などでレビューを実行するか、レビュー内容を提供してください。

## Severity Indicators

Every comment MUST start with a severity tag on the first line:

| Tag | Meaning | Action Required |
|---|---|---|
| `[critical]` | Bugs, security issues, data loss risks | Must fix before merge |
| `[warning]` | Logic errors, performance issues, missing edge cases | Should fix |
| `[suggestion]` | Better approaches, readability improvements | Consider fixing |
| `[nit]` | Style, naming, minor preferences | Optional |
| `[question]` | Unclear intent, needs clarification | Reply needed |
| `[praise]` | Good pattern, clever solution | No action needed |

## Comment Writing Rules

- Put the severity tag alone on the first line: `[severity]`
- Follow with the message body starting on the next line
- Use concise, direct language (1-3 sentences max)
- For `[praise]` and items needing no action, explicitly state no action is needed
- Write in the same language as the codebase comments (default: English)
- Include a brief rationale when the issue isn't self-evident
- For code fixes, use a GitHub suggestion block (see below)

Examples:
```
[critical]
Unbounded query without LIMIT can cause OOM on large tables.

[warning]
This catch block swallows the error silently. Consider logging or re-throwing.

[suggestion]
Extract this into a helper — same pattern appears in 3 places.

[nit]
Prefer `const` over `let` since this is never reassigned.

[question]
Is this fallback intentional? The default value differs from the type's zero value.

[praise]
Clean separation of concerns here. No action needed.
```

## GitHub Suggestion Blocks

When the fix is a concrete, small change to a specific line, append a ` ```suggestion ` block after the message. The PR author can apply it directly with one click.

````
[warning]
`TECM-**` is shell glob notation, not a regex. Use `TECM-\d+` instead.

```suggestion
Extract `TECM-\d+` pattern from the branch name. If not found, ask:
```
````

Rules:
- The suggestion block replaces exactly the line(s) the comment is attached to
- For multi-line suggestions, use `start_line` + `line` to define the range
- Only use suggestion blocks when the replacement is unambiguous — avoid for structural rewrites

## Workflow

### Step 1: Collect Review Findings

Gather all review findings from the session. For each finding, extract:
- **File path** (relative to repo root)
- **Line number** (specific line in the file, must be within the PR diff)
- **Severity** (map to one of the 6 severity tags)
- **Comment body** (concise description)

If a finding references a line NOT in the PR diff, handle it as follows:
- Find the nearest changed line in the same file and attach the comment there, noting the actual line
- If the file has no changes in the diff, collect it as a general PR comment (not inline)

### Step 2: Determine PR Context

```bash
gh pr view --json number,url,headRefOid --jq '{number, url, head_oid: .headRefOid}'
```

### Step 3: Verify Lines Are in Diff

Get the diff to verify comment positions:

```bash
gh pr diff --name-only
```

For each file with comments, confirm the target lines are within the diff. Use `gh pr diff` to check specific files if needed.

### Step 4: Post PENDING Review

Use the script to create a PENDING review:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/post-pr-review.sh" /path/to/review-payload.json
```

The payload JSON must follow this structure:

```json
{
  "body": "Review summary (optional)",
  "comments": [
    {
      "path": "src/example.ts",
      "line": 42,
      "body": "[warning] This catch block swallows errors silently."
    },
    {
      "path": "src/utils.ts",
      "line": 10,
      "side": "RIGHT",
      "body": "[suggestion] Consider using a Map for O(1) lookup."
    }
  ]
}
```

Field reference:
- `body`: Overall review summary (optional, can be empty string)
- `comments[].path`: File path relative to repo root (required)
- `comments[].line`: Line number in the file (required, must be in diff)
- `comments[].body`: Comment text starting with severity tag (required)
- `comments[].side`: `RIGHT` (new code, default) or `LEFT` (deleted code)
- `comments[].start_line`: First line for multi-line comments (optional)
- `comments[].start_side`: Side for start_line (optional)

### Step 5: Post General Comments (if any)

For findings that cannot be attached to specific diff lines, post them as part of the review body or as separate PR comments:

```bash
gh pr comment --body "[severity] General comment about non-diff code..."
```

### Step 6: Report to User

After posting, report:
1. Number of inline comments posted by severity
2. Number of general comments (if any)
3. The PR URL where the user can review and submit

Example output:
> PENDING レビューを投稿しました。
>
> - [critical]: 1 件
> - [warning]: 3 件
> - [suggestion]: 2 件
> - [nit]: 1 件
> - [praise]: 2 件
>
> PR で確認して送信してください: https://github.com/owner/repo/pull/123

## Important Rules

- **NEVER submit the review** - Always create as PENDING. The user submits manually.
- **NEVER use `APPROVE` or `REQUEST_CHANGES` event** - Only PENDING reviews.
- **Every comment must have a severity tag** - No exceptions.
- **Verify line numbers** - Comments on lines outside the diff will fail.
- **Keep comments concise** - Verbose reviews waste reviewer time.
- **Batch all comments** - Use a single review, not multiple individual comments.
