---
name: drafting-message
description: >-
  Draft a short Japanese message the user will post themselves — a Slack reply
  or share, a request to QA / design / support / another team, a Notion or PR
  comment — sized and worded for the named audience, shown in chat, and copied
  to the clipboard. Never posts anything.
when_to_use: >-
  Use whenever the user wants text to send — "返信案を考えて", "返信を考えて",
  "slack で共有する文章", "依頼文を考えて", "文章を考えて。私が投稿する",
  "QA 向けに書いて", "チームに説明したい", "draft a reply", "write a Slack
  message for me" — and when a pasted message needs an answer. Not for PR
  descriptions, commit messages, or documents that live in a repository.
argument-hint: "[what to say, to whom]"
allowed-tools:
  - Bash(pbcopy:*)
  - Read
---

# Drafting a Message

## Request

$ARGUMENTS

If blank, draft what the conversation was leading to. A pasted message is
the thing to answer.

## Audience first

Name the reader to yourself — engineer, QA, biz, support, designer, another
team, someone outside the company — because the reader fixes the
vocabulary:

- Non-engineers get no file paths, ticket IDs, PR numbers, 「別 PR で対応」,
  or architecture. Say what changes for them and when.
- QA gets what to test and which tenant or environment can be used, not how
  it was built.
- Engineers can get identifiers, but still no diff narration.

When the user pastes an example or a template, match its register, headings
and length exactly, and fill a 概要 line with one sentence.

## Writing

- Slack fits on one screen: three lines for a reply, five for a share. One
  idea per line.
- Lead with the ask or the conclusion; background only if the reader needs
  it to act.
- Plain です・ます in the user's own voice. No opening pleasantries unless
  the reader is outside the company, no 「ご確認のほどよろしくお願いいたします」
  tail, no 「〜させていただきます」, no bullet essay. A sentence that sounds
  generated is cut, not rephrased.
- Only what is known. A guess is marked as one or left out.
- 「短く」 means removing sentences, not compressing them.

## Output

Print the draft alone in a fenced block, then copy it:

```bash
pbcopy <<'EOF'
<draft>
EOF
```

Skip the copy silently when `pbcopy` is unavailable. Do not post to Slack,
Notion, or GitHub even when the tools are at hand — posting is the user's
act.
