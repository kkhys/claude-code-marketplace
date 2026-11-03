#!/usr/bin/env python3
"""Candidate vocabulary and replacements for Hex, mined from the prompts typed
into Claude Code and from Hex's own dictation history.

extract scans ~/.claude/projects/*/*.jsonl for the prompts the user typed
(promptSource "typed" or "queued": tool results, hook output, SDK-driven
turns, and subagent transcripts never carry those), tokenizes them, drops
what Hex already knows and what an earlier run rejected, and prints the
rest as JSON for the agent to judge. Only Latin and katakana words are
candidates: people are never registered, and e-mail addresses, tokens, and
other random-looking strings are cut from the text before anything is
tokenized or quoted. It also prints every dictation Hex pasted in the window
(`hex history`), paired with the prompt the user sent right after it when
that prompt carries a hand-corrected version: the mishearings a tokenizer
cannot see, a wrong kanji above all, for the agent to turn into replacements.

apply registers the agent's decisions through `hex vocabulary add` and
`hex settings set dictation_processing.default_mode`, remembers the rejected
terms so they are never proposed again, and advances the window so the next
run only reads newer prompts. State survives in one JSON file.
"""

import argparse
import collections
import datetime as dt
import difflib
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
# The Global mode holds the replacements Hex applies to every transcript.
MODE_KEY = "dictation_processing.default_mode"
HISTORY_LIMIT = 10000
# A dictation is paired with the first prompt sent this soon after it that
# carries at least this share of its characters in order (in blocks of two
# or more: single characters match by chance in Japanese).
PAIR_WINDOW = dt.timedelta(minutes=30)
PAIR_MIN_MATCH = 0.7

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
    # A labelled value: NOTION_TOKEN=…, "password": "…", パスワード: …,
    # token is …, api_key => '…', トークンは …
    re.compile(r"(?i)(?<![A-Za-z0-9])[\w-]*(?:token|secret|password|passwd|pwd|api[_-]?key|credential"
               r"|パスワード|トークン|シークレット|秘密鍵|APIキー)[\w-]*[\"']?\s*(?:=>|[:=：＝]|\bis\b|は|が|を)\s*"
               r"(?:Bearer\s+|Basic\s+)?(?:\"[^\"]*\"|'[^']*'|\S+)"),
    re.compile(r"(?i)\bAuthorization\s*[:=]\s*(?:Bearer|Basic)?\s*\S+"),
    re.compile(r"(?i)\bBearer\s+\S+"),
    re.compile(r"(?i)\bBasic\s+[A-Za-z0-9+/=]{8,}"),
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
# A one-character replacement would rewrite most of every transcript, and a
# form in more of the retained dictations than this share is a word the user
# says (です, ください), not a mishearing.
MIN_REPLACE_LEN = 2
MAX_REPLACE_SHARE = 0.2
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


def warn(message):
    print(f"warning: {message}", file=sys.stderr)


def run_hex(hex_bin, *args):
    """(parsed --json reply, error) of a hex command; the reply is None when hex could not answer."""
    try:
        result = subprocess.run([hex_bin, *args, "--json"], capture_output=True, text=True, check=False)
    except OSError as error:
        return None, f"cannot run {hex_bin}: {error}"
    try:
        reply = json.loads(result.stdout)
    except ValueError:
        reply = None
    if result.returncode != 0:
        message = reply.get("message") if isinstance(reply, dict) else None
        return None, message or result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
    if not isinstance(reply, dict):
        return None, f"hex {' '.join(args)} returned no JSON"
    return reply, None


def known_spellings(hex_bin):
    """Every term and sounds-like Hex holds, lower-cased; None when Hex cannot answer."""
    reply, error = run_hex(hex_bin, "vocabulary", "list")
    if reply is None:
        warn(error)
        return None
    known = set()
    for entry in reply.get("entries", []):
        known.add(entry.get("term", "").lower())
        known.update(spelling.lower() for spelling in entry.get("sounds_like", []))
    known.discard("")
    return known


def default_mode(hex_bin):
    """(the Global mode as hex settings holds it, error); the mode is None when Hex cannot answer."""
    reply, error = run_hex(hex_bin, "settings", "get", MODE_KEY)
    if reply is None:
        return None, error
    for setting in reply.get("settings", []):
        if setting.get("key") == MODE_KEY and isinstance(setting.get("value"), dict):
            return setting["value"], None
    return None, f"hex settings get {MODE_KEY} returned no value"


def dictations(hex_bin, since=None, until=None):
    """(timestamp, text) for every dictation Hex pasted in the window, or retains at all without one.

    None when the history cannot be read.
    """
    window = [] if since is None else ["--since", since.isoformat(), "--until", until.isoformat()]
    reply, error = run_hex(hex_bin, "history", *window, "--limit", str(HISTORY_LIMIT), "--oldest-first")
    if reply is None:
        warn(error)
        return None
    if reply.get("truncated"):
        warn(f"hex history holds more than {HISTORY_LIMIT} dictations in the window; narrow it with --since")
        return None
    rows = []
    for entry in reply.get("entries", []):
        stamp = entry.get("timestamp_ms")
        text = entry.get("final_text", "")
        # An edit of selected text is not a transcript of the user's words.
        if entry.get("kind", "dictation") == "dictation" and isinstance(stamp, (int, float)) and text.strip():
            rows.append((dt.datetime.fromtimestamp(stamp / 1000, dt.timezone.utc), text))
    return rows


def squash(text):
    return re.sub(r"\s+", " ", text).strip()


def correction(dictated, timestamp, prompts):
    """What the user sent in place of a dictation they edited before sending.

    None when the dictation went out unchanged or no prompt in the window
    carries it. `prompts` is (timestamp, cleaned text), oldest first.
    """
    for sent_at, text in prompts:
        if not timestamp <= sent_at <= timestamp + PAIR_WINDOW:
            continue
        if dictated in text:
            return None
        matcher = difflib.SequenceMatcher(None, dictated, text, autojunk=False)
        blocks = [block for block in matcher.get_matching_blocks() if block.size >= 2]
        if blocks and sum(block.size for block in blocks) >= PAIR_MIN_MATCH * len(dictated):
            # The excerpt spans the matched blocks plus the dictation's unmatched
            # head and tail, so a correction at either end is still shown.
            first, last = blocks[0], blocks[-1]
            start = max(0, first.b - first.a)
            end = min(len(text), last.b + last.size + len(dictated) - (last.a + last.size))
            return text[start:end]
    return None


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
    surface = surface.strip(".-_+#")
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
        # clean() already redacted these; checked again so the surface that
        # was validated is the surface that is emitted.
        if FILE_NAME.search(surface) or secret_shaped(surface):
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

    prompts = list(human_prompts(args.projects_dir, since))
    candidates, prompt_count, session_count = collect(prompts)
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

    history = dictations(hex_bin, since, now)
    mode, mode_error = default_mode(hex_bin)
    if mode is None:
        warn(mode_error)
    sent = sorted((timestamp, squash(clean(raw))) for _, timestamp, raw in prompts)
    heard = []
    for timestamp, raw in history or []:
        text = squash(clean(raw))
        if not text:
            continue
        row = {"dictated": text}
        corrected = correction(text, timestamp, sent)
        if corrected:
            row["sent"] = corrected
        heard.append(row)

    output = {
        "since": since.isoformat(),
        "until": now.isoformat(),
        "prompts": prompt_count,
        "sessions": session_count,
        "hex": hex_bin,
        "vocabulary_checked": known is not None,
        "history_checked": history is not None and mode is not None,
        "ignored_total": len(ignored),
        "candidates": rows[: args.limit],
        "omitted": max(0, len(rows) - args.limit),
        "dictations": heard,
        # Heard forms only: what a rule expands to is the user's own text and
        # may be anything, so it never reaches the agent.
        "replacements": [r["matched_phrase"] for r in (mode or {}).get("replacements", [])
                         if isinstance(r.get("matched_phrase"), str) and r["matched_phrase"].strip()
                         and not redacted(r["matched_phrase"])],
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
        die('decisions must be a JSON object with "add", "replace", and "ignore"', 2)
    adds = decisions.get("add", [])
    replaces = decisions.get("replace", [])
    ignores = decisions.get("ignore", [])
    if not isinstance(adds, list) or not isinstance(replaces, list) or not isinstance(ignores, list):
        die('"add", "replace", and "ignore" must be lists', 2)
    for entry in adds:
        term = entry.get("term") if isinstance(entry, dict) else None
        spellings = entry.get("sounds_like", []) if isinstance(entry, dict) else None
        if not isinstance(term, str) or not term.strip():
            die(f'every add needs a non-empty "term": {entry!r}', 2)
        if not isinstance(spellings, list) or any(not isinstance(s, str) or not s.strip() or "," in s for s in spellings):
            die(f'"sounds_like" of {term!r} must be a list of non-empty strings without commas', 2)
        for value in [term, *spellings]:
            check_term(value)
    for entry in replaces:
        source = entry.get("from") if isinstance(entry, dict) else None
        target = entry.get("to") if isinstance(entry, dict) else None
        if not isinstance(source, str) or not source.strip() or not isinstance(target, str):
            die(f'every replace needs a non-empty "from" and a string "to": {entry!r}', 2)
        if source.strip() == target.strip():
            die(f'a replace must change its text: {source!r}', 2)
        if len(source.strip()) < MIN_REPLACE_LEN:
            die(f'"from" must be at least {MIN_REPLACE_LEN} characters: {source!r}', 2)
        check_term(source)
        if target.strip():
            check_term(target)
    for term in ignores:
        if not isinstance(term, str) or not term.strip():
            die(f"every ignore must be a non-empty string: {term!r}", 2)
        check_term(term)
    return adds, replaces, ignores


def redacted(value):
    """True when clean() would cut part of the text: a credential or identifier shape is in it."""
    value = value.strip()
    return clean(value).strip() != value or any(secret_shaped(m.group(0)) for m in ALNUM_RUN.finditer(value))


def check_term(value):
    """Refuse what no vocabulary entry looks like: the agent reads untrusted prompt text."""
    value = value.strip()
    if len(value) > MAX_TERM_LEN or not value.isprintable():
        die(f"{value[:MAX_TERM_LEN]!r} is too long or not printable for a vocabulary entry", 2)
    if redacted(value):
        die(f"{value!r} looks like a credential or an identifier, not a name", 2)


def check_dictated(hex_bin, replaces):
    """Refuse a replacement for a form Hex never pasted: the rule rewrites only what was actually said."""
    history = dictations(hex_bin)
    if history is None:
        die("cannot read hex history, so the replacements cannot be checked against what was dictated")
    spoken = [squash(clean(text)) for _, text in history]
    for entry in replaces:
        source = entry["from"].strip()
        hits = sum(source in text for text in spoken)
        if hits == 0:
            die(f"{source!r} appears in no dictation Hex retains; a replacement rewrites only what was actually dictated", 2)
        if hits > MAX_REPLACE_SHARE * len(spoken):
            die(f"{source!r} is in {hits} of the {len(spoken)} dictations Hex retains; a form that common is a word, not a mishearing", 2)


def add_replacements(hex_bin, replaces):
    """Append the new replacements to the Global mode in one write; (replaced, failed)."""
    mode, error = default_mode(hex_bin)
    if mode is None:
        return [], [{"from": entry["from"].strip(), "error": error} for entry in replaces]
    existing = {r.get("matched_phrase"): r.get("output", "") for r in mode.get("replacements", [])}
    replaced, new = [], []
    for entry in replaces:
        source, target = entry["from"].strip(), entry["to"].strip()
        if source in existing:
            # Hex's own output for the form is not echoed: it is the user's text.
            replaced.append({"from": source, "changed": False})
            continue
        existing[source] = target
        new.append({"matched_phrase": source, "output": target})
        replaced.append({"from": source, "to": target, "changed": True})
    if not new:
        return replaced, []
    mode["replacements"] = [*mode.get("replacements", []), *new]
    _, error = run_hex(hex_bin, "settings", "set", MODE_KEY, json.dumps(mode, ensure_ascii=False))
    if error:
        return [r for r in replaced if not r["changed"]], [{"from": r["matched_phrase"], "error": error} for r in new]
    return replaced, []


def cmd_apply(args):
    adds, replaces, ignores = read_decisions(args.decisions)
    state = load_state(args.state_file)
    hex_bin = resolve_hex(args.hex)
    if replaces:
        check_dictated(hex_bin, replaces)

    added, failed = [], []
    for entry in adds:
        term = entry["term"].strip()
        spellings = [s.strip() for s in entry.get("sounds_like", [])]
        command = ["vocabulary", "add", term]
        if spellings:
            command += ["--sounds-like", ",".join(spellings)]
        reply, error = run_hex(hex_bin, *command)
        if reply is None:
            failed.append({"term": term, "error": error})
        else:
            added.append({"term": term, "sounds_like": spellings, "changed": reply.get("changed", True),
                          "message": reply.get("message", "")})

    replaced, replace_failures = add_replacements(hex_bin, replaces) if replaces else ([], [])
    failed.extend(replace_failures)

    # The window advances only when every add landed: a run that could not
    # reach Hex must not swallow the prompts it was meant to review.
    if not failed:
        state["ignored"] = sorted({*state["ignored"], *(t.strip() for t in ignores)}, key=str.lower)
        state["last_run"] = utc_now().isoformat()
        save_state(args.state_file, state)

    json.dump({
        "added": added,
        "replaced": replaced,
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
    apply.add_argument("--decisions", default="-",
                       help='JSON file {"add": [{"term", "sounds_like"}], "replace": [{"from", "to"}], "ignore": [...]} (default: stdin)')
    apply.set_defaults(func=cmd_apply)

    args = parser.parse_args(argv)
    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
