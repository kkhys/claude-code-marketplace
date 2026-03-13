---
name: uploading-knowledge-gist
description: Upload session knowledge to GitHub Gist as a draft (secret). Use when saving learnings, discoveries, or technical notes from the current session to a Gist.
disable-model-invocation: true
allowed-tools: Bash(gh:*), Read
---

# Upload Session Knowledge to Gist

Save knowledge gained during the current session as a secret (draft) GitHub Gist.

## Security Rules (MUST follow)

Before creating a gist, scan content and REJECT if it contains:

- API keys, tokens, secrets, passwords, credentials
- Personal information (email, phone, address, real names of non-public figures)
- Internal URLs, IP addresses, hostnames
- `.env` file contents or environment variables with values
- Database connection strings
- Private repository paths or proprietary code

If any sensitive content is detected, warn the user and ask them to review before proceeding.

## Workflow

### Step 1: Gather Knowledge

Summarize the session's key learnings. Focus on:

- Technical discoveries (bugs found, root causes, workarounds)
- Architecture decisions and rationale
- Useful commands or code patterns
- Configuration insights
- Troubleshooting steps that worked

Exclude:
- Raw code diffs (already in git)
- Conversation meta-commentary
- Temporary debugging output

### Step 2: Format Content

Create a Markdown file with this structure:

```markdown
# Session Knowledge: <topic>

Date: YYYY-MM-DD

## Context

Brief description of what was being worked on.

## Key Learnings

### <Learning 1 Title>

<Description>

### <Learning 2 Title>

<Description>

## Commands / Snippets

(If applicable)

## References

- Links to relevant docs, issues, PRs
```

### Step 3: Write to Temp File

```bash
tmpfile=$(mktemp /tmp/knowledge-XXXXXX.md)
cat > "$tmpfile" << 'CONTENT'
<formatted content>
CONTENT
echo "$tmpfile"
```

### Step 4: Create Secret Gist

```bash
gh gist create "$tmpfile" --desc "Session Knowledge: <topic> (YYYY-MM-DD)"
```

`gh gist create` without `--public` creates a secret gist by default.

### Step 5: Clean Up

```bash
rm "$tmpfile"
```

### Step 6: Report

Show the user:
- Gist URL
- Brief summary of what was saved

## Notes

- Always create secret gists (never use `--public`)
- Use descriptive filenames: `knowledge-<topic>.md`
- Keep gist content self-contained and useful for future reference
- If no meaningful knowledge was gained in the session, inform the user instead of creating an empty gist
