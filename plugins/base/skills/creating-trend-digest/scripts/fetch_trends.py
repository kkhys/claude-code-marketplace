#!/usr/bin/env python3
"""Fetch trending items for the creating-trend-digest skill.

Sources: Hacker News, Lobsters, GitHub Trending, dev.to, Hatena Bookmark,
Zenn, Qiita. Stdlib only.

Each source failure is isolated: the service is reported with status
"error" and the rest of the run continues, so one flaky API never kills
the digest.

--date switches the run to backfill mode, which reaches only the sources
in BACKFILL_FETCHERS; the rest expose no historical query and are reported
as skipped.
"""

import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from html import unescape
from pathlib import Path

UA = "trend-digest/1.0 (personal research tool)"
TIMEOUT = 15

# TREND_DIGEST_STATE_DIR allows tests to run against an isolated state dir
STATE_DIR_DEFAULT = Path(
    os.environ.get("TREND_DIGEST_STATE_DIR", Path.home() / ".claude" / "trend-digest")
)


def http_get(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as res:
        return res.read().decode("utf-8", errors="replace")


def get_json(url, headers=None):
    return json.loads(http_get(url, headers))


def hours_ago(iso, now):
    if not iso:
        return None
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return max(0.0, (now - dt).total_seconds() / 3600)
    except ValueError:
        return None


def clip(text, limit=200):
    if not text:
        return ""
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(re.sub(r"\s+", " ", text)).strip()
    return text[:limit]


def make_item(title, url, engagement, label, published=None, comments_url=None, excerpt="", extra=""):
    return {
        "title": clip(title, 300),
        "url": url,
        "comments_url": comments_url,
        "engagement": int(engagement or 0),
        "engagement_label": label,
        "published_at": published,
        "excerpt": excerpt,
        "extra": extra,
    }


# --- fetchers ---------------------------------------------------------------


def _hn_items(data):
    items = []
    for h in data.get("hits", []):
        comments = f"https://news.ycombinator.com/item?id={h['objectID']}"
        items.append(make_item(
            h.get("title", ""), h.get("url") or comments,
            (h.get("points") or 0) + (h.get("num_comments") or 0) // 2,
            f"{h.get('points', 0)}pt / {h.get('num_comments', 0)}コメント",
            h.get("created_at"), comments,
            excerpt=clip(h.get("story_text", ""), 150),
        ))
    return items


def fetch_hackernews(cfg):
    limit = cfg.get("fetch_limit", 30)
    data = get_json(f"https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage={limit}")
    return {"status": "ok", "items": _hn_items(data)}


def fetch_lobsters(cfg):
    data = get_json("https://lobste.rs/hottest.json")
    items = []
    for s in data[: cfg.get("fetch_limit", 30)]:
        items.append(make_item(
            s.get("title", ""), s.get("url") or s.get("short_id_url"),
            (s.get("score") or 0) + (s.get("comment_count") or 0) // 2,
            f"{s.get('score', 0)}pt / {s.get('comment_count', 0)}コメント",
            s.get("created_at"), s.get("short_id_url"),
            extra=", ".join(s.get("tags", [])[:4]),
        ))
    return {"status": "ok", "items": items}


def fetch_github_trending(cfg):
    html = http_get("https://github.com/trending?since=daily")
    items = []
    for block in html.split('<article class="Box-row"')[1:]:
        m = re.search(r'<h2[^>]*>\s*<a[^>]*\shref="/([^"]+)"', block)
        if not m:
            continue
        repo = m.group(1)
        desc = re.search(r'<p class="col-9[^"]*">\s*(.*?)\s*</p>', block, re.S)
        lang = re.search(r'itemprop="programmingLanguage">([^<]+)<', block)
        today = re.search(r"([\d,]+)\s+stars?\s+today", block)
        total = re.search(r'/stargazers"[^>]*>\s*(?:<[^>]+>\s*)*([\d,]+)', block, re.S)
        stars_today = int(today.group(1).replace(",", "")) if today else 0
        total_stars = total.group(1) if total else "?"
        label = f"+{stars_today} stars today / 計{total_stars}"
        if lang:
            label += f" / {lang.group(1)}"
        items.append(make_item(
            repo, f"https://github.com/{repo}", stars_today, label,
            excerpt=clip(desc.group(1) if desc else "", 200),
            extra=lang.group(1) if lang else "",
        ))
    if not items:
        raise RuntimeError("GitHub Trending のHTML解析が0件 (ページ構造変更の可能性)")
    return {"status": "ok", "items": items[: cfg.get("fetch_limit", 30)]}


def fetch_devto(cfg):
    limit = min(cfg.get("fetch_limit", 30), 30)
    data = get_json(f"https://dev.to/api/articles?top=1&per_page={limit}")
    items = []
    for a in data:
        items.append(make_item(
            a.get("title", ""), a.get("url"),
            (a.get("positive_reactions_count") or 0) + (a.get("comments_count") or 0),
            f"{a.get('positive_reactions_count', 0)}リアクション / {a.get('comments_count', 0)}コメント",
            a.get("published_at"), a.get("url"),
            excerpt=clip(a.get("description", ""), 200),
            extra=", ".join((a.get("tag_list") or [])[:4]),
        ))
    return {"status": "ok", "items": items}


def safe_xml(xml_text):
    # Entity-expansion (billion laughs) and XXE both require a DTD; feeds
    # from these services never legitimately contain one, so reject outright
    # instead of pulling in defusedxml as a dependency.
    if re.search(r"<!\s*(DOCTYPE|ENTITY)", xml_text, re.I):
        raise RuntimeError("XML に DTD 宣言が含まれるため解析を拒否")
    return ET.fromstring(xml_text)


def _rss_items(xml_text):
    root = safe_xml(xml_text)
    for el in root.iter():
        if el.tag.endswith("}item") or el.tag == "item":
            fields = {}
            for c in el:
                tag = c.tag.split("}")[-1]
                if tag not in fields:
                    fields[tag] = c.text or ""
            yield fields


def fetch_hatena(cfg):
    items, seen_urls = [], set()
    for cat in cfg.get("hatena_categories", ["it"]):
        url = ("https://b.hatena.ne.jp/hotentry.rss" if cat == "all"
               else f"https://b.hatena.ne.jp/hotentry/{cat}.rss")
        for f in _rss_items(http_get(url)):
            link = f.get("link", "")
            if not link or link in seen_urls:
                continue
            seen_urls.add(link)
            count = int(f.get("bookmarkcount") or 0)
            items.append(make_item(
                f.get("title", ""), link, count, f"{count} users",
                f.get("date") or None,
                f"https://b.hatena.ne.jp/entry/{link}",
                excerpt=clip(f.get("description", ""), 200),
                extra=f.get("subject", ""),
            ))
    items.sort(key=lambda x: x["engagement"], reverse=True)
    return {"status": "ok", "items": items[: cfg.get("fetch_limit", 30)]}


def fetch_zenn(cfg):
    limit = cfg.get("fetch_limit", 30)
    data = get_json(f"https://zenn.dev/api/articles?order=daily&count={limit}")
    items = []
    for a in data.get("articles", []):
        liked = a.get("liked_count") or 0
        bookmarked = a.get("bookmarked_count") or 0
        items.append(make_item(
            a.get("title", ""), f"https://zenn.dev{a.get('path', '')}",
            liked + bookmarked,
            f"いいね{liked} / ブクマ{bookmarked}",
            a.get("published_at"),
        ))
    return {"status": "ok", "items": items}


def fetch_qiita(cfg):
    feed = http_get("https://qiita.com/popular-items/feed")
    root = safe_xml(feed)
    ns = {"a": "http://www.w3.org/2005/Atom"}
    entries = []
    for e in root.findall("a:entry", ns):
        link = e.find("a:link", ns)
        href = link.get("href") if link is not None else ""
        title = e.findtext("a:title", "", ns)
        published = e.findtext("a:published", "", ns)
        if href:
            entries.append((title, href, published))
    entries = entries[: min(cfg.get("fetch_limit", 30), 25)]

    token = os.environ.get("QIITA_ACCESS_TOKEN")
    headers = {"Authorization": f"Bearer {token}"} if token else None

    def detail(entry):
        title, href, published = entry
        m = re.search(r"/items/([0-9a-f]+)", href)
        likes = stocks = 0
        excerpt = ""
        if m:
            try:
                d = get_json(f"https://qiita.com/api/v2/items/{m.group(1)}", headers)
                likes = d.get("likes_count") or 0
                stocks = d.get("stocks_count") or 0
                excerpt = clip(d.get("body", ""), 200)
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
                pass  # keep the entry; it just scores low without counts
        return make_item(title, href, likes + stocks,
                         f"LGTM{likes} / ストック{stocks}", published, excerpt=excerpt)

    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        items = list(pool.map(detail, entries))
    return {"status": "ok", "items": items}


# --- backfill (--date) ------------------------------------------------------

BACKFILL_NOTE = "過去日付を照会できるAPIがないため取得不可"


def day_window(date_str):
    """Local-day [start, end) for date_str, as timezone-aware datetimes.

    A naive datetime's .astimezone() resolves the local offset in effect on
    that date, so this stays correct across a DST boundary.
    """
    start = datetime.strptime(date_str, "%Y-%m-%d").astimezone()
    return start, start + timedelta(days=1)


def fetch_hackernews_at(cfg, start, end):
    """Top stories submitted during the window.

    An empty query on /search ranks by Algolia's custom ranking, which for
    the HN index is points — the same popularity order as the front page.
    """
    query = urllib.parse.urlencode({
        "tags": "story",
        "numericFilters": (f"created_at_i>={int(start.timestamp())},"
                           f"created_at_i<{int(end.timestamp())}"),
        "hitsPerPage": cfg.get("fetch_limit", 30),
    })
    data = get_json(f"https://hn.algolia.com/api/v1/search?{query}")
    items = _hn_items(data)
    if not items:
        raise RuntimeError("該当期間の記事が0件")
    return {"status": "ok", "items": items}


BACKFILL_FETCHERS = {
    "hackernews": fetch_hackernews_at,
}


SERVICES = [
    {"id": "hackernews", "label": "Hacker News", "market": "global", "fetch": fetch_hackernews},
    {"id": "lobsters", "label": "Lobsters", "market": "global", "fetch": fetch_lobsters},
    {"id": "github", "label": "GitHub Trending", "market": "global", "fetch": fetch_github_trending},
    {"id": "devto", "label": "dev.to", "market": "global", "fetch": fetch_devto},
    {"id": "hatena", "label": "はてなブックマーク", "market": "japan", "fetch": fetch_hatena},
    {"id": "zenn", "label": "Zenn", "market": "japan", "fetch": fetch_zenn},
    {"id": "qiita", "label": "Qiita", "market": "japan", "fetch": fetch_qiita},
]


# --- discussion comments ------------------------------------------------------

COMMENT_LIMIT = 8
COMMENT_CLIP = 300


def fetch_hn_comments(item):
    m = re.search(r"id=(\d+)", item.get("comments_url") or "")
    if not m:
        return []
    data = get_json(f"https://hn.algolia.com/api/v1/items/{m.group(1)}")
    out = []
    for child in data.get("children") or []:
        text = clip(child.get("text") or "", COMMENT_CLIP)
        if text:
            out.append(text)
        if len(out) >= COMMENT_LIMIT:
            break
    return out


def fetch_lobsters_comments(item):
    m = re.search(r"/s/([0-9a-z]+)", item.get("comments_url") or "")
    if not m:
        return []
    data = get_json(f"https://lobste.rs/s/{m.group(1)}.json")
    out = []
    for comment in data.get("comments") or []:
        text = clip(comment.get("comment_plain") or comment.get("comment") or "", COMMENT_CLIP)
        if text:
            out.append(text)
        if len(out) >= COMMENT_LIMIT:
            break
    return out


def fetch_hatena_comments(item):
    # jsonlite returns the latest bookmarks; commented ones are a minority,
    # so scan the whole page and keep the first COMMENT_LIMIT with text.
    url = "https://b.hatena.ne.jp/entry/jsonlite/?url=" + urllib.parse.quote(item["url"], safe="")
    data = get_json(url)
    out = []
    for bookmark in (data or {}).get("bookmarks") or []:
        text = clip(bookmark.get("comment") or "", COMMENT_CLIP)
        if text:
            out.append(text)
        if len(out) >= COMMENT_LIMIT:
            break
    return out


COMMENT_FETCHERS = {
    "hackernews": fetch_hn_comments,
    "lobsters": fetch_lobsters_comments,
    "hatena": fetch_hatena_comments,
}


def _attach(services, fetchers, top_n, key):
    """Run per-item fetchers over the top items of matching services and
    store truthy results under `key`. Failures leave the item untouched;
    enrichment is best-effort by design."""
    if top_n <= 0:
        return

    jobs = []
    for svc in services:
        fetcher = fetchers.get(svc["id"])
        if fetcher is None or svc["status"] != "ok":
            continue
        jobs.extend((fetcher, item) for item in svc["items"][:top_n])

    def run_job(job):
        fetcher, item = job
        try:
            return fetcher(item)
        except Exception:  # noqa: BLE001 - enrichment is best-effort
            return None

    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(run_job, jobs))
    for (_, item), value in zip(jobs, results):
        if value:
            item[key] = value


def attach_comments(services, cfg):
    _attach(services, COMMENT_FETCHERS, cfg.get("comments_top_n", 10), "comments")


# --- article content --------------------------------------------------------

# Sources without a comment fetcher get the article body instead, so the
# digest can summarize the article itself at the same depth.

CONTENT_CLIP = 2000


def fetch_github_content(item):
    m = re.search(r"github\.com/([^/?#]+/[^/?#]+)", item["url"] or "")
    if not m:
        return ""
    text = http_get(f"https://api.github.com/repos/{m.group(1)}/readme",
                    headers={"Accept": "application/vnd.github.raw+json"})
    return clip(text, CONTENT_CLIP)


def fetch_devto_content(item):
    m = re.search(r"dev\.to/([^/?#]+/[^/?#]+)", item["url"] or "")
    if not m:
        return ""
    data = get_json(f"https://dev.to/api/articles/{m.group(1)}")
    return clip(data.get("body_markdown") or "", CONTENT_CLIP)


def fetch_zenn_content(item):
    m = re.search(r"zenn\.dev/[^/]+/articles/([^/?#]+)", item["url"] or "")
    if not m:
        return ""
    data = get_json(f"https://zenn.dev/api/articles/{m.group(1)}")
    return clip((data.get("article") or {}).get("body_html") or "", CONTENT_CLIP)


def fetch_qiita_content(item):
    m = re.search(r"/items/([0-9a-f]+)", item["url"] or "")
    if not m:
        return ""
    token = os.environ.get("QIITA_ACCESS_TOKEN")
    headers = {"Authorization": f"Bearer {token}"} if token else None
    data = get_json(f"https://qiita.com/api/v2/items/{m.group(1)}", headers)
    return clip(data.get("body") or "", CONTENT_CLIP)


CONTENT_FETCHERS = {
    "github": fetch_github_content,
    "devto": fetch_devto_content,
    "zenn": fetch_zenn_content,
    "qiita": fetch_qiita_content,
}


def attach_article_content(services, cfg):
    _attach(services, CONTENT_FETCHERS, cfg.get("articles_top_n", 10), "content")


# --- scoring / state --------------------------------------------------------


def add_base_scores(items, now):
    """base_score = engagement percentile within the service batch (75%)
    + freshness decay (25%), on a 0-100 scale. Interest weighting is applied
    later by Claude using the profile."""
    n = len(items)
    if n == 0:
        return
    order = sorted(range(n), key=lambda i: items[i]["engagement"])
    for rank, idx in enumerate(order):
        pct = rank / (n - 1) if n > 1 else 1.0
        h = hours_ago(items[idx].get("published_at"), now)
        fresh = (0.75 if h is None else
                 1.0 if h < 6 else 0.9 if h < 12 else
                 0.75 if h < 24 else 0.55 if h < 48 else 0.35)
        items[idx]["base_score"] = round(100 * (0.75 * pct + 0.25 * fresh))


def apply_seen(items, seen, today):
    for it in items:
        first = seen.get(it["url"])
        it["seen_before"] = bool(first and first < today)
        if not first:
            seen[it["url"]] = today


def bootstrap(state_dir, skill_dir):
    state_dir.mkdir(parents=True, exist_ok=True)
    created = []
    for name, default in (("config.json", "default-config.json"),
                          ("profile.md", "default-profile.md")):
        dst = state_dir / name
        if not dst.exists():
            shutil.copy(skill_dir / "assets" / default, dst)
            created.append(name)
    return created


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill-dir", required=True, type=Path)
    parser.add_argument("--state-dir", default=STATE_DIR_DEFAULT, type=Path)
    parser.add_argument("--date", help="過去日付を遡って取得 (YYYY-MM-DD)")
    parser.add_argument("--force", action="store_true",
                        help="--date で既存の raw.json を上書きする")
    args = parser.parse_args()

    created = bootstrap(args.state_dir, args.skill_dir)
    config_path = args.state_dir / "config.json"
    try:
        cfg = json.loads(config_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return f"config.json が不正な JSON です ({config_path}): {e}"
    disabled = set(cfg.get("disabled_sources", []))

    today = datetime.now().astimezone().strftime("%Y-%m-%d")
    target = args.date or today
    try:
        window = day_window(target)
    except ValueError:
        return f"--date は YYYY-MM-DD 形式で指定してください: {args.date}"
    # Asking for today by date is just a normal run; only the past needs the
    # reduced source set.
    backfill = target < today

    # Freshness is measured against the end of the target day so that a
    # backfilled run scores the same way the live run would have.
    now = window[1] if backfill else datetime.now(timezone.utc)
    run_dir = args.state_dir / "runs" / target
    raw_path = run_dir / "raw.json"
    if backfill and raw_path.exists() and not args.force:
        return (f"{raw_path} が既に存在します。全ソース揃った実行結果を"
                "縮小版で潰さないよう中断しました。上書きするには --force を付けてください")
    run_dir.mkdir(parents=True, exist_ok=True)

    seen_path = args.state_dir / "seen.json"
    seen = json.loads(seen_path.read_text(encoding="utf-8")) if seen_path.exists() else {}

    def run(svc):
        if svc["id"] in disabled:
            return {"status": "skipped", "note": "config.json の disabled_sources で無効化", "items": []}
        fetch = BACKFILL_FETCHERS.get(svc["id"]) if backfill else svc["fetch"]
        if fetch is None:
            return {"status": "skipped", "note": BACKFILL_NOTE, "items": []}
        try:
            return fetch(cfg, *window) if backfill else fetch(cfg)
        except Exception as e:  # noqa: BLE001 - isolate any source failure
            return {"status": "error", "note": f"{type(e).__name__}: {e}", "items": []}

    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(run, SERVICES))

    keep = cfg.get("items_per_service", 10) * 2
    services = []
    for svc, res in zip(SERVICES, results):
        items = res.get("items", [])
        add_base_scores(items, now)
        items.sort(key=lambda x: x.get("base_score", 0), reverse=True)
        items = items[:keep]
        apply_seen(items, seen, target)
        services.append({
            "id": svc["id"], "label": svc["label"], "market": svc["market"],
            "status": res["status"], "note": res.get("note", ""), "items": items,
        })

    attach_comments(services, cfg)
    attach_article_content(services, cfg)

    raw_path.write_text(json.dumps({
        "date": target,
        "fetched_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "backfill": backfill,
        "items_per_service": cfg.get("items_per_service", 10),
        "services": services,
    }, ensure_ascii=False, indent=1), encoding="utf-8")

    # seen.json is written only after raw.json succeeds: URLs marked seen
    # without a surviving raw file would never surface in any digest. A
    # backfill never writes it — recording a past date out of order would
    # rewrite "first seen" for URLs later runs already claimed.
    if not backfill:
        if len(seen) > 8000:
            seen = dict(sorted(seen.items(), key=lambda kv: kv[1], reverse=True)[:6000])
        seen_path.write_text(json.dumps(seen, ensure_ascii=False), encoding="utf-8")

    if created:
        print(f"BOOTSTRAPPED: {', '.join(created)} を {args.state_dir} に作成 (要ユーザー確認)")
    if backfill:
        print(f"BACKFILL: {target} を遡って取得 (対応ソースのみ。他は skipped)")
    for s in services:
        note = f" — {s['note']}" if s["note"] else ""
        print(f"{s['id']:<11} {s['status']:<8} {len(s['items']):>3} items{note}")
    print(f"raw: {raw_path}")
    print(f"run_dir: {run_dir}")

    # Partial failures are tolerated by design, but a run that produced
    # nothing to digest must fail loudly. Backfill deliberately skips most
    # sources, so judge it on the ones it actually attempted.
    attempted = [s for s in services if s["status"] != "skipped"]
    if not attempted or all(s["status"] == "error" for s in attempted):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
