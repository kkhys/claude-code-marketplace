---
description: Create a timestamped memo with ULID in ~/projects/private-content/memo/
argument-hint: <memo content>
allowed-tools: Bash(bash:*)
model: claude-haiku-4-5
disable-model-invocation: true
---

# Memo Command

Create a new memo entry with the following content:

```
$ARGUMENTS
```

## Instructions

Execute the shell script with the memo content:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/create-memo.sh" "$ARGUMENTS"
```

The script will:
- Generate a ULID-like identifier
- Create a timestamped directory in `~/projects/private-content/memo/YYYYMMDD_HHMMSS/`
- Write `index.md` with frontmatter (id, createdAt) and content

## Example

Input: `/memo Astroで開発をする際はAstro Docs MCPを使うのがおすすめ。`

Execute: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/create-memo.sh" "Astroで開発をする際はAstro Docs MCPを使うのがおすすめ。"`

Output:
```
Memo created successfully
  Directory: ~/projects/private-content/memo/20260111_223042/
  File: index.md
  ID: 01kengh578ah895bt7284sm3ns
  Created: 2026-01-11 22:30:42
```
