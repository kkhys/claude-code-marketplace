---
name: creating-trend-digest
description: Collect today's trends from 7 sources (HN, Lobsters, GitHub Trending, dev.to, Hatena, Zenn, Qiita), score them against a personal interest profile, and publish the digest to trends.kkhys.me
argument-hint: "[今日の関心・調整指示 (省略可)]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(python3:*)
  - Bash(git:*)
  - Bash(pnpm:*)
  - Bash(open:*)
---

# Creating Trend Digest

Generate a personalized daily trend report: fetch trending items from tech
news sources, score them against the user's interest profile, and publish
the digest as one JSON file in the me repo, which builds and deploys the
Astro site at trends.kkhys.me (`apps/trends`). The profile lives in
`~/.claude/trend-digest/` and improves with every piece of feedback
— treat this as a long-running secretary role, not a one-shot report.

User adjustments for this run (may be empty):

```
$ARGUMENTS
```

If `$ARGUMENTS` contains instructions (e.g. "セキュリティ中心で", "件数少なめ"),
honor them for this run only. Only update the profile when the user asks for a
lasting change or gives feedback.

## Style

Everything you write for the digest — headline, lead, highlight reasons,
summaries — states facts plainly: what the item is, where it trended, what
changed. No recommendations, no calls to action, no addressing the reader
(「〜すべき」「おすすめ」「注目」「チェックしよう」「試す価値あり」の類は
書かない). No emoji.

## Workflow

### 1. Fetch

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/fetch_trends.py" --skill-dir "${CLAUDE_SKILL_DIR}"
```

First run bootstraps `~/.claude/trend-digest/{config.json,profile.md}` from
bundled defaults — if the output says `BOOTSTRAPPED`, tell the user at the end
that the profile was created from defaults and is worth reviewing.

The script fetches all sources in parallel, computes `base_score` (0-100,
engagement percentile × freshness — see `references/scoring.md`), marks
`seen_before` for URLs already shown on previous days, and writes
`runs/<date>/raw.json`. Failed sources appear with `status: "error"` — never
abort the run for them; their note is shown on the site instead.

### 2. Score and summarize

Read `~/.claude/trend-digest/profile.md` and the `raw.json` path printed by
the script. For each service, work through its items and produce the display
list (top `items_per_service` per service after filtering):

- **Drop** items matching the profile's 除外テーマ.
- **interest** (1-3 stars) from the profile's 興味テーマ: high match → 3
  stars, mid → 2 stars, weak/none → 1 star. Stars are an annotation only —
  they must not affect the ranking, so the list stays a flat view of what
  actually trended.
- **score** = `base_score` unchanged. Sort descending.
- **category**: short label derived from the profile themes (e.g. "AI/開発",
  "セキュリティ", "キャリア"). Leave empty if nothing fits.
- **summary**: one Japanese sentence (≤60 chars): what it is and why it is
  relevant to the profile. Write from title/excerpt and your own knowledge —
  do not fetch each article.
- **discussion_summary**: only for items whose raw.json entry has a
  `comments` array (the fetch script attaches top comments to the top
  `comments_top_n` items of HN / Lobsters / はてなブックマーク): summarize
  the discussion in 2-3 Japanese sentences — the main points raised and, when
  visible, the split of opinion. Facts only, no editorializing. Items without
  `comments` get `""`.

### 3. Write the digest

Compose the digest for the top of the page:

- `headline`: one line capturing today's dominant story or pattern.
- `lead`: 2-3 sentences connecting today's trends across sources.
- `highlights`: 3-5 cross-service picks, each with a one-line `reason`
  stating the observed signal (e.g. appears on multiple services, unusually
  high engagement, direct hit on a high-interest theme). Prefer items
  appearing in multiple services and high-interest matches.

### 4. Publish

Resolve the site repo: read `site_repo` from
`~/.claude/trend-digest/config.json` (expand `~`). If the key is missing,
use `~/projects/github.com/kkhys/me` and add the key to config.json (Edit)
so the next run reads it. `$REPO` below stands for that path.

Preflight — if any check fails, stop and report what failed plus the manual
recovery step. Never checkout, stash, or force anything:

1. `git -C $REPO ls-files apps/trends/package.json` prints a path
   (repo exists and contains the trends app)
2. `git -C $REPO rev-parse --abbrev-ref HEAD` prints `main`
3. `git -C $REPO status --porcelain -- apps/trends/src/content/runs` is
   empty (dirt elsewhere in the repo is fine — only this file gets committed)
4. `git -C $REPO pull --ff-only` succeeds

Write `$REPO/apps/trends/src/content/runs/<date>.json` in this shape:

```json
{
  "date": "2026-08-08",
  "generated_at": "2026-08-08T09:30:00+09:00",
  "digest": {
    "headline": "...", "lead": "...",
    "highlights": [{"title": "...", "url": "...", "service_label": "Hacker News", "reason": "..."}]
  },
  "markets": [
    {"id": "japan", "label": "日本", "services": [
      {"id": "hatena", "label": "はてなブックマーク", "status": "ok", "note": "",
       "items": [{"title": "...", "url": "...", "comments_url": "...", "score": 87,
                  "engagement_label": "313 users", "category": "AI/開発", "interest": 3,
                  "summary": "...", "discussion_summary": "", "seen_before": false,
                  "extra": ""}]}
    ]},
    {"id": "global", "label": "グローバル", "services": ["... hackernews, lobsters, github, devto ..."]}
  ]
}
```

- 2-space indent, UTF-8 without `\uXXXX` escapes, trailing newline. The
  filename must equal the `date` field.
- Every string field is required — write `""` for missing values, never null.
- Carry `status`/`note` from raw.json through unchanged (skipped/error
  services render as a notice). Japan services: hatena, zenn, qiita.
  Global: hackernews, lobsters, github, devto.
- The site's zod schema (`apps/trends/src/content.config.ts`) is strict:
  unknown or retired fields (e.g. `action_note`) fail the build. When the
  schema changes, update it, this JSON example, and the existing files in
  `runs/` together.
- Re-running on the same day overwrites the file. If git shows no diff for
  it after writing, report that the deployed digest is already current and
  stop here.

Then commit → deploy → push, in this order — deploy must succeed before
anything is pushed:

```bash
git -C $REPO add apps/trends/src/content/runs/<date>.json
git -C $REPO commit -m "chore(trends): add digest for <date>"
pnpm -C $REPO deploy:trends
git -C $REPO push origin main
open https://trends.kkhys.me/
```

Use `update digest for <date>` as the message when overwriting. Failure
handling:

- Build fails on a zod error → fix the JSON, `git add` it, then
  `git -C $REPO commit --amend --no-edit` and retry the deploy (max 2
  retries). The commit is not pushed yet, so amending is safe.
- Deploy fails otherwise → retry once. If it still fails, do NOT push; leave
  the commit in place and report the error with the recovery commands
  (`pnpm -C $REPO deploy:trends`, then `git -C $REPO push origin main`).
  If it looks like expired credentials, suggest `wrangler login`.
- Push fails → the site is already live; report that only
  `git -C $REPO push origin main` needs re-running.

### 5. Report

Reply with 2-3 sentences: today's main takeaway, anything unusual (failed
sources, bootstrap notice), the published URL (https://trends.kkhys.me/),
and the commit hash.

## Feedback → profile updates (the secretary loop)

When the user reacts to a digest ("Rustは興味ない", "この記事良かった",
"はてなの総合カテゴリも見たい"), update the state files immediately:

- `profile.md` — move themes between high/mid/low, add new themes, extend
  除外テーマ. Generalize: "この記事不要" usually means a theme, not one URL.
  Append a dated entry to フィードバックログ recording feedback → change.
- `config.json` — hatena_categories, items_per_service, disabled_sources,
  site_repo.

Prefer small durable adjustments over drastic rewrites; the log exists so
changes remain traceable and reversible.

## Setup and troubleshooting

Optional `QIITA_ACCESS_TOKEN` (rate-limit headroom) and notes on future
X/Grok integration: `references/setup.md`. Scoring details and tuning:
`references/scoring.md`.
