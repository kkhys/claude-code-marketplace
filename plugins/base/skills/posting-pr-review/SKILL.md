---
name: posting-pr-review
description: Post review comments to a GitHub PR as a PENDING review using the post-pr-review.sh workflow script and a 6-level severity tag system ([critical]/[warning]/[suggestion]/[nit]/[question]/[praise]).
when_to_use: >-
  Use after completing code review (pr-review-toolkit:review-pr,
  code-reviewer, silent-failure-hunter, or any review agent) to submit
  structured feedback. Always use when posting, submitting, or sending
  review comments to a PR — do not call the GitHub review API directly
  without this skill's workflow.
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
  - Bash(cat:*)
  - Bash(mktemp:*)
  - Bash(rm:*)
  - Bash(bash:*)
  - Read
---

# Post PR Review as PENDING

Post structured review comments to a GitHub PR as a PENDING review. The review is always created in PENDING state — never APPROVE or REQUEST_CHANGES. This is because submitting immediately would notify the PR author before the user has reviewed and edited the comments on GitHub.

<!-- claude:start -->
## PR Context

!`gh pr view --json number,title,url 2>/dev/null || echo "No open PR found for the current branch"`
<!-- claude:end -->
<!-- portable:start -->
## PR Context

Identify the PR the review targets:

```bash
gh pr view --json number,title,url
```
<!-- portable:end -->

## Prerequisites

This skill requires review results from the current session. Acceptable sources:
- `pr-review-toolkit:review-pr` or similar review agent output
- Review findings manually provided by the user

If no review data exists in the current session, prompt the user:
> セッション内にレビュー結果が見つかりません。先にレビューを実行するか、レビュー内容を提供してください。

## Severity Tags

Every comment must start with a severity tag on its own line. This gives the PR author a quick way to scan the comment list and know what action is needed.

| Tag | Meaning |
|---|---|
| `[critical]` | Bugs, security, data loss — must fix before merge |
| `[warning]` | Logic errors, performance, edge cases — should fix |
| `[suggestion]` | Better approaches, readability — consider |
| `[nit]` | Style, naming — optional |
| `[question]` | Unclear intent — reply needed |
| `[praise]` | Good pattern — no action needed |

Format: tag alone on the first line, body starting on the next line (1-3 sentences).

```
[warning]
This catch block swallows the error silently. Consider logging or re-throwing.
```

## Suggestion Blocks

When the fix is a concrete, small change, use a GitHub suggestion block. The PR author can apply it with one click, which significantly speeds up the review cycle.

````
[warning]
`TECM-**` is shell glob notation, not a regex.

```suggestion
const match = branchName.match(/TECM-[0-9]+/);
```
````

- The suggestion block replaces exactly the line(s) the comment is attached to
- For multi-line suggestions, use `start_line` + `line` to define the range
- Only use when the replacement is unambiguous — avoid for structural rewrites

## Workflow

### 1. Collect and Validate Findings

Extract from each finding:
- File path (relative to repo root)
- Line number
- Severity tag
- Comment body (including suggestion blocks where applicable)

Verify that each comment's line number falls within the PR diff using `gh pr diff`. The GitHub API rejects comments on lines outside the diff, so this validation is mandatory.

Handling lines outside the diff:
- Attach to the nearest changed line in the same file, noting the actual line number in the body
- If the file has no changes in the diff → post as a general PR comment in Step 3

### 2. Post PENDING Review

Create a payload JSON and pass it to the script:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/post-pr-review.sh" /path/to/payload.json
```

Payload:
```json
{
  "body": "Review summary (optional)",
  "comments": [
    {
      "path": "src/example.ts",
      "line": 42,
      "body": "[warning]\nThis catch block swallows errors silently."
    },
    {
      "path": "src/utils.ts",
      "start_line": 10,
      "line": 15,
      "body": "[suggestion]\nExtract this into a helper.\n\n```suggestion\nconst result = extractHelper(input);\n```"
    }
  ]
}
```

Fields:
- `path`: File path relative to repo root (required)
- `line`: Line number within the diff (required)
- `body`: Comment starting with severity tag (required)
- `side`: `RIGHT` (default, new code) or `LEFT` (deleted code)
- `start_line` / `start_side`: For multi-line comments (optional)

### 3. Post General Comments

For findings that reference files not in the diff, post as general PR comments:

```bash
gh pr comment --body "[severity]
Comment about non-diff code..."
```

### 4. Report

After posting, report severity counts and the PR URL in Japanese:

> PENDING レビューを投稿しました。
>
> - [critical]: 1 件
> - [warning]: 3 件
> - [suggestion]: 2 件
>
> PR で確認して送信してください: https://github.com/owner/repo/pull/123
