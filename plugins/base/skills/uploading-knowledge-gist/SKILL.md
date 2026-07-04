---
name: uploading-knowledge-gist
description: Save session knowledge to a secret GitHub Gist with built-in security scanning and content curation.
argument-hint: "[topic]"
allowed-tools:
  - Bash(gh:*)
  - Read
disable-model-invocation: true
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
