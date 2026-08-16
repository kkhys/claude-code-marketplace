---
name: creating-handoff
description: Compact the current conversation into a handoff document under ~/.claude/handoffs/ so a fresh session can continue the work
argument-hint: "[what the next session will do]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash(mkdir:*)
  - Bash(git:*)
  - Bash(gh:*)
---

# Creating Handoff

Write a handoff document summarising the current conversation so a fresh
agent can continue the work. The reader has none of this context, so the file
must stand on its own — but it is a transit document, not a spec: enough to
resume, nothing that already lives elsewhere.

## Next session

$ARGUMENTS

If blank, the next session continues the current task. Otherwise tailor the
whole document to that focus — what it needs to know, in the order it needs
it.

## Session context

- Timestamp: !`date '+%Y%m%d-%H%M'`
- Repo: !`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`
- Branch: !`git branch --show-current 2>/dev/null`
- Recent commits: !`git log --oneline -5 2>/dev/null`
- PR: !`gh pr view --json number,url,title 2>/dev/null || echo "no PR"`

## Document structure

Write in English; quote the user's own requirements verbatim in their
original language.

```markdown
# Handoff: <title>

Written <YYYY-MM-DD HH:mm> from <repo>@<branch> — for: <next-session focus>

## State
<done / in progress / blocked — one line each>

## Decisions
<each with its reason; the rejected alternative in one clause>

## Open questions

## Artifacts
<one path or URL per line: plan file (~/.claude/plans/...), spec, PR,
commits (short sha), branch, gist>

## Environment notes
<commands that worked, what failed and why, gotchas>

## Suggested skills
<`plugin:skill` — when the next agent should invoke it via the Skill tool>

## Next steps
<ordered>
```

Do not duplicate content already captured in other artifacts (specs, plans,
ADRs, issues, commits, diffs). Reference them by path or URL instead, and
verify each referenced path exists (Read / Glob) before citing it. Under
Suggested skills, name only skills present in this environment, by their
`plugin:skill` name.

## Content safety

A handoff travels — into another session, another machine, sometimes another
person's hands — so treat it as semi-public. Before writing, scan the draft
for credentials, tokens, API keys, internal hostnames, PII, `.env` values,
and database connection strings; replace each with `<REDACTED>`. If a
redacted value looks load-bearing for the next session, or you are unsure
whether something is sensitive, flag it and ask the user before writing.

## Writing the file

1. `mkdir -p ~/.claude/handoffs`
2. Name the file `<YYYYMMDD-HHmm>-<slug>.md`, using the timestamp above. The
   slug is 2–5 lowercase ASCII words joined by hyphens, taken from the
   next-session focus (or the session topic when the focus is blank). A
   Japanese topic becomes short English words, not romaji.
3. Write it once with the Write tool.

## Report

Reply in Japanese with the absolute path, a one-line summary of what the
document covers, what was redacted (or 「秘匿情報なし」), and how to resume:

```
新しいセッションで「~/.claude/handoffs/<file> を読んで続きをやって」と伝えてください。
```
