---
name: creating-memo
description: Create a timestamped memo with ULID in ~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/
argument-hint: "<memo content>"
allowed-tools:
  - Bash(bash:*)
disable-model-invocation: true
---

# Create Memo

Create a new memo entry with the following content:

```
$ARGUMENTS
```

## Instructions

Execute the bundled shell script with the memo content:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" "$ARGUMENTS"
```

The script will:
- Generate a ULID-like identifier
- Create a timestamped directory in `~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/YYYYMMDD_HHMMSS/`
- Write `index.md` with frontmatter (id, createdAt) and content

## Example

Input: `/creating-memo Astroで開発をする際はAstro Docs MCPを使うのがおすすめ。`

Execute: `bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" "Astroで開発をする際はAstro Docs MCPを使うのがおすすめ。"`

Output:
```
Memo created successfully
  Directory: ~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/20260111_223042/
  File: index.md
  ID: 01kengh578ah895bt7284sm3ns
  Created: 2026-01-11 22:30:42
```
