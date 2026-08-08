---
name: creating-trend-digest
description: Collect today's trends from 7 sources (HN, Lobsters, GitHub Trending, dev.to, Hatena, Zenn, Qiita), score them against a personal interest profile, and open an HTML digest
argument-hint: "[今日の関心・調整指示 (省略可)]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(python3:*)
  - Bash(open:*)
---

# Creating Trend Digest

Generate a personalized daily trend report: fetch trending items from tech
news sources, score them against the user's interest profile, and render an
HTML digest grouped by market (日本 / グローバル) and service. The profile
lives in `~/.claude/trend-digest/` and improves with every piece of feedback
— treat this as a long-running secretary role, not a one-shot report.

User adjustments for this run (may be empty):

```
$ARGUMENTS
```

If `$ARGUMENTS` contains instructions (e.g. "セキュリティ中心で", "件数少なめ"),
honor them for this run only. Only update the profile when the user asks for a
lasting change or gives feedback.

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
abort the run for them; their note is shown in the HTML instead.

### 2. Score and summarize

Read `~/.claude/trend-digest/profile.md` and the `raw.json` path printed by
the script. For each service, work through its items and produce the display
list (top `items_per_service` per service after filtering):

- **Drop** items matching the profile's 除外テーマ.
- **interest** (1-3 stars) and multiplier from the profile's 興味テーマ:
  high match → 3 stars ×1.3, mid → 2 stars ×1.0, weak/none → 1 star ×0.6.
- **score** = `min(100, round(base_score × multiplier))`. Sort descending.
- **category**: short label derived from the profile themes (e.g. "AI/開発",
  "セキュリティ", "キャリア"). Leave empty if nothing fits.
- **summary**: one Japanese sentence (≤60 chars): what it is + why it matters
  to this user. Write from title/excerpt and your own knowledge — do not fetch
  each article. No emoji.

### 3. Write the digest

Compose the digest for the top of the page:

- `headline`: one line capturing today's dominant story or pattern.
- `lead`: 2-3 sentences connecting today's trends to the user's interests.
- `highlights`: 3-5 cross-service picks — the items the user must not miss,
  each with a one-line `reason`. Prefer items appearing in multiple services
  (strong trend signal) and high-interest matches.
- `action_note` (optional): one concrete suggestion — e.g. a blog-post angle
  (発信ネタ is a profile theme), a tool worth trying, a discussion worth reading.

### 4. Render and open

Write `runs/<date>/enriched.json` in this shape, then:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/build_html.py" --input <run_dir>/enriched.json --output <run_dir>/digest.html
open <run_dir>/digest.html
```

```json
{
  "date": "2026-08-08",
  "generated_at": "2026-08-08T09:30:00+09:00",
  "digest": {
    "headline": "...", "lead": "...",
    "highlights": [{"title": "...", "url": "...", "service_label": "Hacker News", "reason": "..."}],
    "action_note": "..."
  },
  "markets": [
    {"id": "japan", "label": "日本", "services": [
      {"id": "hatena", "label": "はてなブックマーク", "status": "ok", "note": "",
       "items": [{"title": "...", "url": "...", "comments_url": "...", "score": 87,
                  "engagement_label": "313 users", "category": "AI/開発", "interest": 3,
                  "summary": "...", "seen_before": false, "extra": ""}]}
    ]},
    {"id": "global", "label": "グローバル", "services": ["... hackernews, lobsters, github, devto ..."]}
  ]
}
```

Carry `status`/`note` from raw.json through unchanged (skipped/error services
render as a notice). Japan services: hatena, zenn, qiita. Global: hackernews,
lobsters, github, devto.

### 5. Report

Reply with 2-3 sentences: today's main takeaway, anything unusual (failed
sources, bootstrap notice), and the digest file path.

## Feedback → profile updates (the secretary loop)

When the user reacts to a digest ("Rustは興味ない", "この記事良かった",
"はてなの総合カテゴリも見たい"), update the state files immediately:

- `profile.md` — move themes between high/mid/low, add new themes, extend
  除外テーマ. Generalize: "この記事不要" usually means a theme, not one URL.
  Append a dated entry to フィードバックログ recording feedback → change.
- `config.json` — hatena_categories, items_per_service, disabled_sources.

Prefer small durable adjustments over drastic rewrites; the log exists so
changes remain traceable and reversible.

## Setup and troubleshooting

Optional `QIITA_ACCESS_TOKEN` (rate-limit headroom) and notes on future
X/Grok integration: `references/setup.md`. Scoring details and tuning:
`references/scoring.md`.
