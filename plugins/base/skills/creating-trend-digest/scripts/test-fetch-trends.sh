#!/usr/bin/env bash
set -euo pipefail

# Offline tests for fetch_trends.py backfill mode (--date): the day window,
# source selection, and the guards around state.
#
# Backfill reaches only Hacker News, so it silently produces a much thinner
# digest than a live run. The guards tested here are what keep that from
# doing damage: overwriting a full 7-source raw.json with a 1-source one, or
# rewriting seen.json with an out-of-order date so later runs mislabel what
# is new.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR

python3 - "$TEST_DIR" <<'PY'
import json
import sys
import tempfile
from datetime import datetime, timedelta
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
      set(ft.BACKFILL_FETCHERS) == {"hackernews"}, sorted(ft.BACKFILL_FETCHERS))
check("every backfill source is a real service",
      set(ft.BACKFILL_FETCHERS) <= service_ids, sorted(set(ft.BACKFILL_FETCHERS) - service_ids))


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
                  for i in ("lobsters", "github", "devto", "hatena", "zenn", "qiita")))
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
