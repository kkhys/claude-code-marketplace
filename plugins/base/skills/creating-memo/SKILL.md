---
name: creating-memo
description: Create a timestamped memo with ULID in ~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/
argument-hint: "[--tag TAG] [--comment MEMO_ID] <memo content>"
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

Parse `$ARGUMENTS` yourself: if it starts with `--tag TAG` and/or `--comment MEMO_ID`, extract those values and treat the rest as the memo content. Then execute the bundled shell script, passing each part as its own quoted argument (never forward `$ARGUMENTS` unquoted — the content may contain shell metacharacters):

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" "<memo content>"
bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" --tag "<TAG>" "<memo content>"
bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" --comment "<MEMO_ID>" "<memo content>"
bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" --tag "<TAG>" --comment "<MEMO_ID>" "<memo content>"
```

The script will:
- Generate a ULID-like identifier
- Create a timestamped directory in `~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/YYYYMMDD_HHMMSS/`
- Write `index.md` with frontmatter (`id`, `createdAt`, optional `tag`, optional `comment`) and content

### Optional flags

- `--tag TAG` — categorize the memo (e.g. `drink_log`, `boxing`)
- `--comment MEMO_ID` — link this memo as a follow-up/reply to a previous memo, referencing its `id` (the ULID from a prior memo's frontmatter)

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

### With a tag

Input: `/creating-memo --tag drink_log ハリオの水出しコーヒーボトルは簡単に作れておすすめ。`

Execute: `bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" --tag drink_log "ハリオの水出しコーヒーボトルは簡単に作れておすすめ。"`

### As a follow-up to a previous memo

Input: `/creating-memo --comment 01kybqps0g15hbv4byxa4h6bw6 割と欲しいけど送料が高くて買えない。`

Execute: `bash "${CLAUDE_SKILL_DIR}/scripts/creating-memo.sh" --comment 01kybqps0g15hbv4byxa4h6bw6 "割と欲しいけど送料が高くて買えない。"`
