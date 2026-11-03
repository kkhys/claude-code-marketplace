#!/usr/bin/env python3
"""Candidate vocabulary for Hex, mined from the prompts typed into Claude Code.

extract scans ~/.claude/projects/*/*.jsonl for the prompts the user typed
(promptSource "typed" or "queued": tool results, hook output, SDK-driven
turns, and subagent transcripts never carry those), tokenizes them, drops
what Hex already knows and what an earlier run rejected, and prints the
rest as JSON for the agent to judge. Only Latin and katakana words are
candidates: people are never registered, and e-mail addresses, tokens, and
other random-looking strings are cut from the text before anything is
tokenized or quoted.

apply registers the agent's decisions through `hex vocabulary add`, remembers
the rejected terms so they are never proposed again, and advances the window
so the next run only reads newer prompts. State survives in one JSON file.
"""

import argparse
import collections
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HUMAN_PROMPT_SOURCES = {"typed", "queued"}
# Orca submits its hand-off brief as if the user had typed it.
GENERATED_PROMPT_PREFIXES = ("Continue work from the prior Orca session",)
DEFAULT_HEX = "/Applications/Hex.app/Contents/MacOS/hex"
DEFAULT_SINCE = "7d"
STATE_VERSION = 1

# Blocks the user pasted or Claude Code injected, not words they would say,
# and the shapes a credential or a personal identifier takes. Cut before
# tokenizing so none of it reaches a candidate or a quoted context.
STRIP = [
    re.compile(r"<pasted_content\b[^>]*>.*?</pasted_content\b[^>]*>", re.S),
    re.compile(r"<system-reminder>.*?</system-reminder>", re.S),
    re.compile(r"```.*?```", re.S),
    re.compile(r"`[^`\n]*`"),
    re.compile(r"(?<![A-Za-z0-9])[A-Za-z][A-Za-z0-9+.\-]*://\S+"),
    re.compile(r"\S+:\S+@\S+"),
    re.compile(r"\[Image #\d+\]"),
    re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+"),
    re.compile(r"(?<![\w.])@[\w.\-]+"),
    re.compile(r"(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}(?![A-Za-z0-9])"),
    re.compile(r"(?<![A-Za-z0-9])AIza[0-9A-Za-z_\-]{35}"),
    re.compile(r"(?<![A-Za-z0-9])ya29\.[0-9A-Za-z_.\-]+"),
    re.compile(r"(?<![A-Za-z0-9])(?:ghp|gho|ghu|ghs|ghr|github_pat|sk|xox[abprs]|npm|glpat|dop_v1|pypi|hf)[_-][A-Za-z0-9_\-]{8,}"),
    re.compile(r"(?<![A-Za-z0-9])eyJ[A-Za-z0-9_\-]{10,}(?:\.[A-Za-z0-9_\-]+)*"),
    # A labelled value: NOTION_TOKEN=…, "password": "…", パスワード: …, token is …
    re.compile(r"(?i)(?<![A-Za-z0-9])[\w-]*(?:token|secret|password|passwd|pwd|api[_-]?key|credential"
               r"|パスワード|トークン|シークレット|秘密鍵|APIキー)[\w-]*[\"']?\s*(?:[:=：]|\bis\b)\s*(?:Bearer\s+)?[\"']?\S+"),
    re.compile(r"\+?\d[\d\-() ]{8,}\d"),
]

LATIN = re.compile(r"(?<![A-Za-z0-9_/.\-@#])[A-Za-z][A-Za-z0-9+#.\-]*[A-Za-z0-9+#](?![A-Za-z0-9_/])")
# Wider than LATIN on purpose: a hash or key may start with a digit or carry
# underscores, and redaction must see every such run, not only candidates.
ALNUM_RUN = re.compile(r"[A-Za-z0-9][A-Za-z0-9_+#.\-]*")
KATAKANA = re.compile(r"[ァ-ヺー]{2,}")
FILE_NAME = re.compile(r"\.(?:tsx?|jsx?|mjs|cjs|json|ya?ml|toml|md|sh|py|nix|lock|html|css|png|jpe?g|svg|pdf|csv|txt|log)$", re.I)
HEX_HASH = re.compile(r"^[0-9a-f]{7,}$")
# A bare login typed without its @: lower-case letters ending in digits.
HANDLE = re.compile(r"^[a-z]+\d{2,}$")
# A key or hash that escaped the prefix patterns: no name is this long, and
# letters mixed with digits past this length is how generated secrets look.
RANDOM_MIN_LEN = 20
RANDOM_MAX_LEN = 32
# Longest term or spelling apply accepts; the agent judges candidates, it
# does not invent paragraphs.
MAX_TERM_LEN = 64
# English a transcript already spells right; the ignore list absorbs the tail.
STOPWORDS = set("""
a about after again all also an and any are as at back be because been before
being between both but by can could did do does doing done down during each
either else even every few first for from get give go good got had has have
having he her here him his how however if in into is it its just keep last
let like make many may me might more most much must my need new next no not
now of off ok okay on once one only or other our out over own per please put
same say see set she should since so some still such sure than that the their
them then there these they this those through to too under until up upon us
use used using very via want was way we well were what when where whether
which while who why will with without would yes yet you your
""".split())

CONTEXT_RADIUS = 28
CONTEXTS_PER_TERM = 3


def die(message, code=1):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(code)


def utc_now():
    return dt.datetime.now(dt.timezone.utc)


def parse_timestamp(value):
    if not isinstance(value, str):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def parse_since(value, now):
    """'3d', '12h', 'YYYY-MM-DD', or an ISO timestamp, as a UTC datetime."""
    relative = re.fullmatch(r"(\d+)([dh])", value)
    if relative:
        amount, unit = int(relative.group(1)), relative.group(2)
        return now - dt.timedelta(**{"days" if unit == "d" else "hours": amount})
    parsed = parse_timestamp(value)
    if parsed is None:
        die(f"--since must be Nd, Nh, YYYY-MM-DD, or an ISO timestamp, got {value!r}", 2)
    return parsed


def default_state_file():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(base, "registering-hex-vocabulary", "state.json")


def load_state(path):
    try:
        with open(path, encoding="utf-8") as f:
            state = json.load(f)
    except FileNotFoundError:
        return {"version": STATE_VERSION, "last_run": None, "ignored": []}
    except (OSError, ValueError) as error:
        die(f"cannot read state file {path}: {error}")
    if not isinstance(state, dict) or not isinstance(state.get("ignored", []), list):
        die(f"state file {path} is not the expected shape; delete it to start over")
    state.setdefault("version", STATE_VERSION)
    state.setdefault("last_run", None)
    state.setdefault("ignored", [])
    return state


def save_state(path, state):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".state-", suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def resolve_hex(explicit):
    return explicit or shutil.which("hex") or DEFAULT_HEX


def known_spellings(hex_bin):
    """Every term and sounds-like Hex holds, lower-cased; None when Hex cannot answer."""
    try:
        result = subprocess.run([hex_bin, "vocabulary", "list", "--json"], capture_output=True, text=True, check=False)
    except OSError as error:
        print(f"warning: cannot run {hex_bin}: {error}", file=sys.stderr)
        return None
    if result.returncode != 0:
        print(f"warning: {hex_bin} vocabulary list failed: {result.stderr.strip() or result.stdout.strip()}", file=sys.stderr)
        return None
    try:
        entries = json.loads(result.stdout).get("entries", [])
    except ValueError:
        print("warning: hex vocabulary list returned no JSON", file=sys.stderr)
        return None
    known = set()
    for entry in entries:
        known.add(entry.get("term", "").lower())
        known.update(spelling.lower() for spelling in entry.get("sounds_like", []))
    known.discard("")
    return known


def prompt_text(record):
    content = record.get("message", {}).get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(part.get("text", "") for part in content if isinstance(part, dict) and part.get("type") == "text")
    return ""


def human_prompts(projects_dir, since):
    """(session id, timestamp, text) for every prompt the user typed since `since`."""
    since_epoch = since.timestamp()
    try:
        projects = sorted(os.listdir(projects_dir))
    except FileNotFoundError:
        die(f"projects directory not found: {projects_dir}")
    for project in projects:
        project_dir = os.path.join(projects_dir, project)
        if not os.path.isdir(project_dir):
            continue
        # Only the session files themselves: the directories beside them hold
        # subagent transcripts, whose prompts Claude wrote.
        for name in sorted(os.listdir(project_dir)):
            path = os.path.join(project_dir, name)
            if not name.endswith(".jsonl") or not os.path.isfile(path) or os.path.getmtime(path) < since_epoch:
                continue
            with open(path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    try:
                        record = json.loads(line)
                    except ValueError:
                        continue
                    if record.get("type") != "user" or record.get("promptSource") not in HUMAN_PROMPT_SOURCES:
                        continue
                    timestamp = parse_timestamp(record.get("timestamp"))
                    if timestamp is None or timestamp < since:
                        continue
                    text = prompt_text(record)
                    if text.strip() and not text.lstrip().startswith(GENERATED_PROMPT_PREFIXES):
                        yield record.get("sessionId", name), timestamp, text


def looks_random(surface):
    if len(surface) >= RANDOM_MAX_LEN:
        return True
    return len(surface) >= RANDOM_MIN_LEN and any(c.isdigit() for c in surface)


def secret_shaped(surface):
    return bool(HEX_HASH.match(surface) or HANDLE.match(surface) or looks_random(surface))


def clean(text):
    """Prompt text with every credential or identifier shape removed.

    Runs before tokenizing and before any context is quoted, so a shape the
    patterns know never reaches the candidate list or the agent.
    """
    for pattern in STRIP:
        text = pattern.sub(" ", text)
    return ALNUM_RUN.sub(lambda m: " " if secret_shaped(m.group(0)) else m.group(0), text)


def tokens(text):
    """(kind, surface, start, end) for every candidate in cleaned prompt text."""
    for match in LATIN.finditer(text):
        surface = match.group(0)
        if FILE_NAME.search(surface):
            continue
        if surface.islower() and (len(surface) <= 2 or surface in STOPWORDS):
            continue
        yield "latin", surface, match.start(), match.end()
    for match in KATAKANA.finditer(text):
        yield "katakana", match.group(0), match.start(), match.end()


def snippet(text, start, end):
    left = max(0, start - CONTEXT_RADIUS)
    right = min(len(text), end + CONTEXT_RADIUS)
    piece = text[left:right].replace("\n", " ")
    return ("…" if left > 0 else "") + re.sub(r"\s+", " ", piece).strip() + ("…" if right < len(text) else "")


class Candidate:
    def __init__(self, kind):
        self.kind = kind
        self.count = 0
        self.surfaces = collections.Counter()
        self.prompts = set()
        self.sessions = set()
        self.contexts = []


def collect(prompts):
    """Candidates keyed by lower-cased surface, plus prompt and session counts."""
    candidates = {}
    prompt_ids = set()
    sessions = set()
    for session, timestamp, raw in prompts:
        prompt_id = (session, timestamp.isoformat())
        prompt_ids.add(prompt_id)
        sessions.add(session)
        text = clean(raw)
        seen_in_prompt = set()
        for kind, surface, start, end in tokens(text):
            key = surface.lower()
            candidate = candidates.setdefault(key, Candidate(kind))
            candidate.count += 1
            candidate.surfaces[surface] += 1
            candidate.prompts.add(prompt_id)
            candidate.sessions.add(session)
            if key not in seen_in_prompt and len(candidate.contexts) < CONTEXTS_PER_TERM:
                candidate.contexts.append(snippet(text, start, end))
            seen_in_prompt.add(key)
    return candidates, len(prompt_ids), len(sessions)


def cmd_extract(args):
    now = utc_now()
    state = load_state(args.state_file)
    if args.since:
        since = parse_since(args.since, now)
    elif state.get("last_run"):
        since = parse_timestamp(state["last_run"])
        if since is None:
            die(f"state file {args.state_file} holds an unreadable last_run; delete it to start over")
    else:
        since = parse_since(DEFAULT_SINCE, now)

    hex_bin = resolve_hex(args.hex)
    known = known_spellings(hex_bin)
    ignored = {term.lower() for term in state["ignored"]}

    candidates, prompt_count, session_count = collect(human_prompts(args.projects_dir, since))
    rows = []
    for key, candidate in candidates.items():
        if key in ignored or (known and key in known):
            continue
        surface = candidate.surfaces.most_common(1)[0][0]
        rows.append({
            "term": surface,
            "kind": candidate.kind,
            "count": candidate.count,
            "prompts": len(candidate.prompts),
            "sessions": len(candidate.sessions),
            "variants": [s for s, _ in candidate.surfaces.most_common() if s != surface],
            "contexts": candidate.contexts,
        })
    rows.sort(key=lambda row: (-row["prompts"], -row["count"], row["term"].lower()))

    output = {
        "since": since.isoformat(),
        "until": now.isoformat(),
        "prompts": prompt_count,
        "sessions": session_count,
        "hex": hex_bin,
        "vocabulary_checked": known is not None,
        "ignored_total": len(ignored),
        "candidates": rows[: args.limit],
        "omitted": max(0, len(rows) - args.limit),
    }
    json.dump(output, sys.stdout, ensure_ascii=False, indent=2)
    print()


def read_decisions(path):
    try:
        if path == "-":
            decisions = json.load(sys.stdin)
        else:
            with open(path, encoding="utf-8") as f:
                decisions = json.load(f)
    except (OSError, ValueError) as error:
        die(f"cannot read decisions: {error}", 2)
    if not isinstance(decisions, dict):
        die('decisions must be a JSON object with "add" and "ignore"', 2)
    adds = decisions.get("add", [])
    ignores = decisions.get("ignore", [])
    if not isinstance(adds, list) or not isinstance(ignores, list):
        die('"add" and "ignore" must be lists', 2)
    for entry in adds:
        term = entry.get("term") if isinstance(entry, dict) else None
        spellings = entry.get("sounds_like", []) if isinstance(entry, dict) else None
        if not isinstance(term, str) or not term.strip():
            die(f'every add needs a non-empty "term": {entry!r}', 2)
        if not isinstance(spellings, list) or any(not isinstance(s, str) or not s.strip() or "," in s for s in spellings):
            die(f'"sounds_like" of {term!r} must be a list of non-empty strings without commas', 2)
        for value in [term, *spellings]:
            check_term(value)
    for term in ignores:
        if not isinstance(term, str) or not term.strip():
            die(f"every ignore must be a non-empty string: {term!r}", 2)
        check_term(term)
    return adds, ignores


def check_term(value):
    """Refuse what no vocabulary entry looks like: the agent reads untrusted prompt text."""
    value = value.strip()
    if len(value) > MAX_TERM_LEN or not value.isprintable():
        die(f"{value[:MAX_TERM_LEN]!r} is too long or not printable for a vocabulary entry", 2)
    if clean(value).strip() != value:
        die(f"{value!r} looks like a credential or an identifier, not a name", 2)


def cmd_apply(args):
    adds, ignores = read_decisions(args.decisions)
    state = load_state(args.state_file)
    hex_bin = resolve_hex(args.hex)

    added, failed = [], []
    for entry in adds:
        term = entry["term"].strip()
        spellings = [s.strip() for s in entry.get("sounds_like", [])]
        command = [hex_bin, "vocabulary", "add", term, "--json"]
        if spellings:
            command[4:4] = ["--sounds-like", ",".join(spellings)]
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=False)
        except OSError as error:
            failed.append({"term": term, "error": str(error)})
            continue
        try:
            reply = json.loads(result.stdout)
        except ValueError:
            reply = {}
        if result.returncode == 0:
            added.append({"term": term, "sounds_like": spellings, "changed": reply.get("changed", True),
                          "message": reply.get("message", result.stdout.strip())})
        else:
            failed.append({"term": term, "error": reply.get("message") or result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"})

    # The window advances only when every add landed: a run that could not
    # reach Hex must not swallow the prompts it was meant to review.
    if not failed:
        state["ignored"] = sorted({*state["ignored"], *(t.strip() for t in ignores)}, key=str.lower)
        state["last_run"] = utc_now().isoformat()
        save_state(args.state_file, state)

    json.dump({
        "added": added,
        "failed": failed,
        "ignored_added": len(ignores),
        "ignored_total": len(state["ignored"]),
        "state_file": args.state_file,
        "last_run": state["last_run"] if not failed else None,
    }, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 1 if failed else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--projects-dir", default=os.path.join(os.path.expanduser("~"), ".claude", "projects"),
                        help="Claude Code session root (default: ~/.claude/projects)")
    parser.add_argument("--state-file", default=default_state_file(),
                        help="where last_run and the ignored terms live (default: $XDG_STATE_HOME/registering-hex-vocabulary/state.json)")
    parser.add_argument("--hex", help=f"hex CLI (default: hex on PATH, else {DEFAULT_HEX})")
    commands = parser.add_subparsers(dest="command", required=True)

    extract = commands.add_parser("extract", help="print candidate terms as JSON")
    extract.add_argument("--since", help="Nd, Nh, YYYY-MM-DD, or ISO timestamp; overrides the saved last_run (default: last_run, else 7d)")
    extract.add_argument("--limit", type=int, default=150, help="most frequent candidates to print (default: 150)")
    extract.set_defaults(func=cmd_extract)

    apply = commands.add_parser("apply", help="register decisions through hex and advance the window")
    apply.add_argument("--decisions", default="-", help='JSON file {"add": [{"term", "sounds_like"}], "ignore": [...]} (default: stdin)')
    apply.set_defaults(func=cmd_apply)

    args = parser.parse_args(argv)
    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
