#!/usr/bin/env bash
set -euo pipefail

# Offline tests for fetch_trends.py: the pure parsers of the sources whose
# feeds carry no machine-readable engagement (Techmeme, Reddit, HF Daily
# Papers), tie handling in scoring, and backfill mode (--date) — the day
# window, source selection, and the guards around state.
#
# Backfill reaches only Hacker News and Hugging Face Daily Papers, so it
# silently produces a much thinner digest than a live run. The guards tested
# here are what keep that from doing damage: overwriting a full 10-source
# raw.json with a reduced one, or rewriting seen.json with an out-of-order
# date so later runs mislabel what is new.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR

python3 - "$TEST_DIR" <<'PY'
import json
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

TEST_DIR = Path(sys.argv[1])
sys.path.insert(0, str(TEST_DIR))
import fetch_trends as ft  # noqa: E402

SKILL_DIR = TEST_DIR.parent

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print(f"  ok   {name}")
    else:
        failed += 1
        print(f"  FAIL {name} {detail}")


# --- day_window -------------------------------------------------------------

print("day_window")
start, end = ft.day_window("2026-08-05")
check("starts at local midnight", (start.hour, start.minute, start.second) == (0, 0, 0), start)
check("spans exactly one day", end - start == timedelta(days=1), end - start)
check("is timezone-aware", start.tzinfo is not None and end.tzinfo is not None)
check("matches the requested date", start.strftime("%Y-%m-%d") == "2026-08-05", start)
try:
    ft.day_window("2026/08/05")
    check("rejects a malformed date", False, "no ValueError")
except ValueError:
    check("rejects a malformed date", True)


# --- backfill source selection ---------------------------------------------

print("backfill source selection")
service_ids = {s["id"] for s in ft.SERVICES}
check("only historical sources are wired up",
      set(ft.BACKFILL_FETCHERS) == {"hackernews", "hfpapers"}, sorted(ft.BACKFILL_FETCHERS))
check("every backfill source is a real service",
      set(ft.BACKFILL_FETCHERS) <= service_ids, sorted(set(ft.BACKFILL_FETCHERS) - service_ids))


# --- parsers for sources without engagement counts ---------------------------

print("techmeme parser")
TM_HTML = """
<CITE>Jane Doe / <A HREF="https://wired.example/">Wired</A>:</CITE>
<span id="s0i1" pml="260812p1"></span>
<DIV CLASS="ii"><STRONG CLASS="L2"><A CLASS="ourh" HREF="https://a.example/one">Story one</A></STRONG>&nbsp; &mdash;&nbsp; First excerpt. </DIV>
<span id="s0i2" pml="260812p2"></span>
<DIV CLASS="dbpt">cluster sub-link without a headline</DIV>
<CITE>Bob / <A HREF="https://bb.example/">Bloomberg</A>:</CITE>
<span id="s0i3" pml="260812p3"></span>
<DIV CLASS="ii"><STRONG CLASS="L2"><A CLASS="ourh" HREF="https://b.example/two">Story two</A></STRONG>&nbsp; &mdash;&nbsp; Second excerpt. </DIV>
"""
tm = ft._techmeme_items(TM_HTML, {"260812p1": "2026-08-12T08:00:00-04:00"})
check("keeps only pml spans with a headline", len(tm) == 2, len(tm))
check("page order becomes the engagement signal",
      [i["engagement"] for i in tm] == [2, 1], [i["engagement"] for i in tm])
check("links the external article", tm[0]["url"] == "https://a.example/one", tm[0]["url"])
check("builds the permalink as comments_url",
      tm[0]["comments_url"] == "https://www.techmeme.com/260812/p1#a260812p1",
      tm[0]["comments_url"])
check("keeps the outlet, not the author", tm[0]["extra"] == "Wired", tm[0]["extra"])
check("finds the byline across a cluster boundary", tm[1]["extra"] == "Bloomberg", tm[1]["extra"])
check("strips the mdash separator from the excerpt",
      tm[0]["excerpt"] == "First excerpt.", repr(tm[0]["excerpt"]))
check("joins the RSS date by permalink id",
      tm[0]["published_at"] == "2026-08-12T08:00:00-04:00" and tm[1]["published_at"] is None,
      (tm[0]["published_at"], tm[1]["published_at"]))

print("reddit parser")
REDDIT_XML = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
<entry>
<content type="html">&amp;#32; submitted by &amp;#32; &lt;a href="https://www.reddit.com/user/alice"&gt; /u/alice &lt;/a&gt; &lt;br/&gt; &lt;span&gt;&lt;a href="https://ext.example/post"&gt;[link]&lt;/a&gt;&lt;/span&gt; &amp;#32; &lt;span&gt;&lt;a href="https://www.reddit.com/r/programming/comments/abc/x/"&gt;[comments]&lt;/a&gt;&lt;/span&gt;</content>
<id>t3_abc</id>
<link href="https://www.reddit.com/r/programming/comments/abc/x/" />
<published>2026-08-12T06:00:00+00:00</published>
<title>Link post</title>
</entry>
<entry>
<content type="html">&lt;!-- SC_OFF --&gt;&lt;div class="md"&gt;&lt;p&gt;Self post body.&lt;/p&gt;&lt;/div&gt;&lt;!-- SC_ON --&gt; &amp;#32; submitted by &amp;#32; &lt;a href="https://www.reddit.com/user/bob"&gt; /u/bob &lt;/a&gt; &lt;span&gt;&lt;a href="https://www.reddit.com/r/programming/comments/def/y/"&gt;[link]&lt;/a&gt;&lt;/span&gt; &lt;span&gt;&lt;a href="https://www.reddit.com/r/programming/comments/def/y/"&gt;[comments]&lt;/a&gt;&lt;/span&gt;</content>
<id>t3_def</id>
<link href="https://www.reddit.com/r/programming/comments/def/y/" />
<published>2026-08-12T05:00:00+00:00</published>
<title>Self post</title>
</entry>
</feed>"""
rd = ft._reddit_items(REDDIT_XML, "programming")
check("parses every entry", len(rd) == 2, len(rd))
check("listing order becomes the engagement signal",
      [i["engagement"] for i in rd] == [2, 1], [i["engagement"] for i in rd])
check("extracts the external article link", rd[0]["url"] == "https://ext.example/post", rd[0]["url"])
check("keeps the permalink as comments_url",
      rd[0]["comments_url"] == "https://www.reddit.com/r/programming/comments/abc/x/",
      rd[0]["comments_url"])
check("link posts get no excerpt", rd[0]["excerpt"] == "", repr(rd[0]["excerpt"]))
check("self posts keep their body as the excerpt",
      rd[1]["excerpt"] == "Self post body.", repr(rd[1]["excerpt"]))
check("tags the subreddit", rd[0]["extra"] == "r/programming", rd[0]["extra"])

print("reddit quota scheduling")
import time as _time  # noqa: E402

ft._reddit_schedule({"x-ratelimit-remaining": "3.0", "x-ratelimit-reset": "40"})
gap = ft._reddit_next[0] - _time.monotonic()
check("keeps steady spacing while quota remains",
      0 < gap <= ft._REDDIT_SPACING + 1, gap)
ft._reddit_schedule({"x-ratelimit-remaining": "0.0", "x-ratelimit-reset": "46"})
gap = ft._reddit_next[0] - _time.monotonic()
check("waits out the window once the quota is spent", gap > ft._REDDIT_SPACING, gap)
ft._reddit_schedule({"x-ratelimit-remaining": "0.0", "x-ratelimit-reset": "600"})
gap = ft._reddit_next[0] - _time.monotonic()
check("caps the wait", gap <= ft._REDDIT_MAX_WAIT + 1, gap)
ft._reddit_schedule(None)
gap = ft._reddit_next[0] - _time.monotonic()
check("tolerates missing headers", gap <= ft._REDDIT_SPACING + 1, gap)
ft._reddit_next[0] = 0.0

print("hf papers mapper")
HF_DATA = [
    {"title": "Paper A", "numComments": 4,
     "paper": {"id": "2608.11111", "upvotes": 10,
               "submittedOnDailyAt": "2026-08-12T00:00:00.000Z",
               "summary": "Abstract A", "ai_summary": "Short A"}},
    {"title": "Paper B", "numComments": 0,
     "paper": {"id": "2608.22222", "upvotes": 10,
               "submittedOnDailyAt": "2026-08-12T00:00:00.000Z",
               "summary": "Abstract B"}},
    {"title": "broken entry without a paper id", "paper": {}},
]
hf = ft._hf_items(HF_DATA, 30)
check("drops entries without a paper id", len(hf) == 2, len(hf))
check("engagement is upvotes + comments/2",
      [i["engagement"] for i in hf] == [12, 10], [i["engagement"] for i in hf])
check("links the HF paper page",
      hf[0]["url"] == "https://huggingface.co/papers/2608.11111", hf[0]["url"])
check("labels upvotes and comments",
      hf[0]["engagement_label"] == "▲10 / 4コメント", hf[0]["engagement_label"])
check("prefers ai_summary for the excerpt", hf[0]["excerpt"] == "Short A", hf[0]["excerpt"])
check("falls back to the abstract", hf[1]["excerpt"] == "Abstract B", hf[1]["excerpt"])
check("respects the limit", len(ft._hf_items(HF_DATA, 1)) == 1)


# --- tie handling in scoring --------------------------------------------------

print("add_base_scores ties")
score_now = datetime.now(timezone.utc)
tied = [
    ft.make_item("older of the tie", "https://t.example/1", 5, "",
                 (score_now - timedelta(hours=30)).isoformat()),
    ft.make_item("newer of the tie", "https://t.example/2", 5, "",
                 (score_now - timedelta(hours=1)).isoformat()),
    ft.make_item("clear top", "https://t.example/3", 9, "",
                 (score_now - timedelta(hours=1)).isoformat()),
]
ft.add_base_scores(tied, score_now)
check("the top item scores a full percentile", tied[2]["base_score"] == 100, tied[2]["base_score"])
check("ties are separated by freshness only",
      tied[1]["base_score"] > tied[0]["base_score"],
      (tied[0]["base_score"], tied[1]["base_score"]))
check("ties stay below the clear winner",
      max(tied[0]["base_score"], tied[1]["base_score"]) < tied[2]["base_score"])
same = [ft.make_item(f"i{k}", f"https://s.example/{k}", 7, "",
                     (score_now - timedelta(hours=1)).isoformat()) for k in range(3)]
ft.add_base_scores(same, score_now)
check("an all-tied batch scores uniformly",
      len({i["base_score"] for i in same}) == 1, [i["base_score"] for i in same])


# --- main() with the network stubbed out ------------------------------------

print("main")

STUB_ITEMS = [
    ft.make_item("stub a", "https://example.com/a", 50, "50pt", "2026-08-05T01:00:00Z"),
    ft.make_item("stub b", "https://example.com/b", 10, "10pt", "2026-08-05T02:00:00Z"),
]


def stub_fetch(cfg, start, end):
    return {"status": "ok", "items": [dict(i) for i in STUB_ITEMS]}


def failing_fetch(cfg, start, end):
    raise RuntimeError("stub failure")


def run_main(state_dir, argv_extra, fetchers):
    ft.BACKFILL_FETCHERS = fetchers
    ft.attach_comments = lambda services, cfg: None
    sys.argv = ["fetch_trends.py", "--skill-dir", str(SKILL_DIR),
                "--state-dir", str(state_dir), *argv_extra]
    return ft.main()


original_fetchers = dict(ft.BACKFILL_FETCHERS)
original_attach = ft.attach_comments
original_live = [s["fetch"] for s in ft.SERVICES]
# The live path must never reach the network from a test.
for svc in ft.SERVICES:
    svc["fetch"] = lambda cfg: {"status": "ok", "items": [dict(i) for i in STUB_ITEMS]}
try:
    with tempfile.TemporaryDirectory() as tmp:
        state = Path(tmp)
        rc = run_main(state, ["--date", "2026-08-05"], {"hackernews": stub_fetch})
        raw_path = state / "runs" / "2026-08-05" / "raw.json"
        check("succeeds when a backfill source returns items", rc == 0, rc)
        check("writes raw.json under the target date", raw_path.exists())

        raw = json.loads(raw_path.read_text(encoding="utf-8"))
        by_id = {s["id"]: s for s in raw["services"]}
        check("stamps the target date, not today", raw["date"] == "2026-08-05", raw["date"])
        check("flags the run as a backfill", raw["backfill"] is True)
        check("fetches the historical source", by_id["hackernews"]["status"] == "ok")
        check("skips sources with no archive",
              all(by_id[i]["status"] == "skipped"
                  for i in ("lobsters", "reddit", "github", "devto", "techmeme",
                            "hfpapers", "hatena", "zenn", "qiita")))
        check("explains why they were skipped",
              by_id["zenn"]["note"] == ft.BACKFILL_NOTE, by_id["zenn"]["note"])
        check("leaves seen.json alone", not (state / "seen.json").exists())

        # A second backfill must not clobber the first without --force.
        raw_path.write_text('{"sentinel": true}', encoding="utf-8")
        rc = run_main(state, ["--date", "2026-08-05"], {"hackernews": stub_fetch})
        check("refuses to overwrite an existing run", isinstance(rc, str), rc)
        check("names --force in the refusal", isinstance(rc, str) and "--force" in rc, rc)
        check("leaves the existing file untouched",
              json.loads(raw_path.read_text(encoding="utf-8")) == {"sentinel": True})

        rc = run_main(state, ["--date", "2026-08-05", "--force"], {"hackernews": stub_fetch})
        check("overwrites when --force is given", rc == 0, rc)

    with tempfile.TemporaryDirectory() as tmp:
        state = Path(tmp)
        rc = run_main(state, ["--date", "2026-08-05"], {"hackernews": failing_fetch})
        check("fails when every attempted source errored", rc == 1, rc)

    with tempfile.TemporaryDirectory() as tmp:
        state = Path(tmp)
        rc = run_main(state, ["--date", "2026/08/05"], {})
        check("rejects a malformed --date", isinstance(rc, str), rc)

    with tempfile.TemporaryDirectory() as tmp:
        state = Path(tmp)
        today = datetime.now().astimezone().strftime("%Y-%m-%d")
        # --date pointing at today is a normal run: it must not fall back to
        # the reduced source set.
        rc = run_main(state, ["--date", today], {"hackernews": failing_fetch})
        raw = json.loads((state / "runs" / today / "raw.json").read_text(encoding="utf-8"))
        check("treats --date today as a live run", raw["backfill"] is False)
        check("writes seen.json on a live run", (state / "seen.json").exists())
finally:
    ft.BACKFILL_FETCHERS = original_fetchers
    ft.attach_comments = original_attach
    for svc, fetch in zip(ft.SERVICES, original_live):
        svc["fetch"] = fetch

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
