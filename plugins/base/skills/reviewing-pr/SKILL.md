---
name: reviewing-pr
description: >-
  Review a pull request, or a whole stacked series, and close with a fixed
  verdict block: approve or not, reproducible bugs with steps a human can run,
  findings with nits stripped, regression and feature-flag scope risk, and a
  one-line manual test checklist. Delegates the review itself to
  pr-review-toolkit:review-pr when that plugin is installed.
when_to_use: >-
  Always use when the user hands over a PR URL for review or asks any of the
  follow-ups this skill answers up front — "レビューして", "approve 相当？",
  "再現可能なバグはある？", "デグレの可能性は？", "重箱ではない？",
  "一連の stacked pr のデグレを調査して", "feature flag 外に影響はない？",
  "review this PR", "is this approvable". Not for fixing review comments
  (fixing-review-comments) or watching CI (babysitting-pr).
argument-hint: "[PR URL or number, or the bottom PR of a stack]"
allowed-tools:
  - Skill
  - Agent
  - Bash(gh:*)
  - Bash(git:*)
  - Read
  - Grep
  - Glob
---

# Reviewing a PR

## Target

$ARGUMENTS

If blank, the PR of the current branch (`gh pr view`). When the user says
「一連の stacked pr」, collect the series from the PR given:

```bash
gh pr view <number> --json number,baseRefName,headRefName
gh pr list --state open --limit 100 --json number,baseRefName,headRefName
```

Follow `baseRefName` down until it reaches the trunk, and `headRefName` up
while another open PR uses it as base. Review the layers bottom-up. One
verdict block covers the series; each finding names its PR number.

## Review

Invoke `pr-review-toolkit:review-pr <url>` through the Skill tool when the
plugin is installed. Otherwise read `gh pr diff` yourself and dispatch the
code-reviewer and silent-failure-hunter agents if they exist. The review's
findings feed the block below — do not print them twice.

Scope is the PR's own diff. A pre-existing problem in a touched file gets
one line under 指摘 marked 既存 and never counts against the verdict.

## Verdict block

Always finish with this, in Japanese, headings verbatim:

```markdown
## 判定
approve 相当 / 要修正 — 決め手を 1 行

## 再現可能なバグ
- `path:line` — 症状。再現: <手順>
（なければ「なし」）

## 指摘（重箱を除く）
- [critical|warning] `path:line` — 1〜2 行

## デグレ・影響範囲
- 既存動作:
- feature flag 外:
- main マージ後の本番影響:

## 手動テスト
- [ ] 1 行で 1 ケース
```

Rules that decide each section:

- 判定 is approve 相当 only when 再現可能なバグ is なし and no `[critical]`
  remains. Name the item that decided it.
- A bug is 再現可能 only when you can give steps a human runs without
  changing code: what to open, what to click or paste into the DevTools
  console, what appears versus what should. Prefer the deployed preview
  environment when the repository has one, then local. When you cannot
  reach concrete steps, write 再現手順は未確認 instead of inventing them.
- 重箱 — naming, style, comment wording, optional refactors — does not
  appear at all. A finding stays only if it changes behaviour, correctness,
  security, or performance for a user.
- デグレ names the existing behaviour the diff touches and whether it still
  holds. Behind a feature flag, say what a tenant without the flag sees.
  When the PR merges toward production, say what reaches production.
- 手動テスト: one checkbox per behaviour the reviewer should verify, one
  line each, one to three items, without the console when a click will do.

Posting to GitHub happens only when the user asks; then `posting-pr-review`
carries the 指摘 items and nothing else.
