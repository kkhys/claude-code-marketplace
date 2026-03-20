---
name: uploading-knowledge-gist
description: >-
  Save session knowledge to a secret GitHub Gist with built-in security scanning and content curation. This skill MUST be consulted before creating any knowledge Gist — it contains critical rules for filtering sensitive data (credentials, internal URLs, connection strings) that could leak via semi-public Gist URLs, and guidelines for structuring content so it's scannable and useful months later. Use whenever the user wants to save, record, capture, or preserve learnings, discoveries, findings, insights, or knowledge from the current session — whether to a Gist explicitly or to "somewhere searchable". Also proactively suggest saving at the end of productive sessions. Trigger phrases include "gist に保存", "ナレッジを保存", "知見を残す", "学んだことを保存", "save to gist", "capture findings", "save session knowledge", "どこかにまとめて", "後で見返せるように", or any request to persist technical learnings beyond the current conversation.
model: sonnet
allowed-tools: Bash(gh:*), Read
---

# Upload Session Knowledge to Gist

Save knowledge from the current session as a secret GitHub Gist — searchable, linkable, and available for future reference.

## What makes a good knowledge Gist

The goal is to help future-you (or a teammate) who hits the same problem or needs the same context. Good candidates:

- Bug root causes and the investigation path that found them
- Architecture decisions and the trade-offs considered
- External service quirks or undocumented behavior
- Commands or code patterns that took real effort to figure out
- Configuration that was non-obvious or surprising

Skip what already lives elsewhere — raw diffs belong in git, conversations are ephemeral, temporary debug output has no long-term value.

## Content safety

Secret Gists are unlisted but accessible to anyone with the URL — treat them as semi-public. Before uploading, scan for anything that shouldn't be on the internet: credentials, tokens, API keys, internal hostnames, PII, `.env` values, database connection strings. If found, flag it and ask the user to review before proceeding. This matters because even deleted Gists can persist in caches or forks.

## Creating the Gist

1. Distill the session's learnings into concise Markdown. Adapt the structure to fit the content — a single discovery might need just a paragraph with a heading, while a debugging saga benefits from Context → Investigation → Root Cause → Fix flow. Include the date for temporal context.

2. Create a secret Gist via heredoc:
   ```bash
   gh gist create --desc "Knowledge: <topic> (<YYYY-MM-DD>)" --filename "knowledge-<topic>.md" - <<'GIST_EOF'
   <content>
   GIST_EOF
   ```

3. Report the Gist URL and a one-line summary of what was saved.

## Writing style

Write for someone scanning in 30 seconds to decide if this Gist solves their problem. Short paragraphs, concrete headings, code blocks for commands. Substance over ceremony — no boilerplate sections if there's nothing to put in them.
