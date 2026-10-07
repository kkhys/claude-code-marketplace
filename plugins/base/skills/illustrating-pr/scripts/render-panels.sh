#!/usr/bin/env bash
set -euo pipefail

# Render explainer panels to PNG.
# Usage: render-panels.sh [--wrap-only] [--theme light|dark|both] <out-dir> <panel.html>...
#
# Each input is an HTML fragment: the inside of the 1600x900 canvas defined in
# assets/panel.html. The fragment is wrapped in that skeleton and captured with
# a headless Chromium at device scale 2, giving a 3200x1800 PNG named after the
# fragment: 01-flow.html -> 01-flow.png (light) and 01-flow.dark.png (dark).
# Both themes render by default; attach-explainer.sh pairs them so the posted
# comment follows the viewer's GitHub theme.
#
# A fragment whose content does not fit the canvas is reported as OVERFLOW and
# makes the script exit non-zero, so a clipped picture never reaches a PR by
# accident. --wrap-only writes the wrapped HTML next to where the PNG would go
# and skips the browser, for inspecting a panel or for tests without Chromium.
#
# Browser lookup: $CHROME_BIN, then common install paths, then a Playwright
# cache. Set CHROME_BIN when none of those is the browser you want.

readonly CANVAS_W=1600
readonly CANVAS_H=900
readonly SCALE=2
# Seconds to wait for one panel's PNG and DOM before giving up on it.
readonly RENDER_TIMEOUT=30

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly SKELETON="${SCRIPT_DIR}/../assets/panel.html"

usage() {
  echo "Usage: render-panels.sh [--wrap-only] [--theme light|dark|both] <out-dir> <panel.html>..." >&2
  exit 1
}

wrap_only=0
theme_arg="both"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wrap-only) wrap_only=1; shift ;;
    --theme)
      [[ $# -ge 2 ]] || usage
      theme_arg="$2"
      shift 2
      ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[[ $# -ge 2 ]] || usage

case "${theme_arg}" in
  light|dark) themes=("${theme_arg}") ;;
  both) themes=(light dark) ;;
  *) usage ;;
esac

readonly OUT_DIR="$1"
shift

if [[ ! -f "${SKELETON}" ]]; then
  echo "Error: skeleton not found: ${SKELETON}" >&2
  exit 1
fi

for fragment in "$@"; do
  if [[ ! -f "${fragment}" ]]; then
    echo "Error: panel not found: ${fragment}" >&2
    exit 1
  fi
done

find_chrome() {
  if [[ -n "${CHROME_BIN:-}" ]]; then
    if [[ -x "${CHROME_BIN}" ]]; then
      echo "${CHROME_BIN}"
      return 0
    fi
    echo "Error: CHROME_BIN is not executable: ${CHROME_BIN}" >&2
    return 1
  fi

  local candidate
  local -a app_paths=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
    "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
  )
  for candidate in "${app_paths[@]}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  local -a names=(google-chrome google-chrome-stable chromium chromium-browser chrome microsoft-edge brave-browser)
  for candidate in "${names[@]}"; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
  done

  # Playwright keeps versioned builds; the newest one sorts last.
  local cache
  for cache in "${HOME}/Library/Caches/ms-playwright" "${HOME}/.cache/ms-playwright"; do
    [[ -d "${cache}" ]] || continue
    candidate="$(find "${cache}" -maxdepth 5 -type f \
      \( -path '*/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium' \
         -o -path '*/chromium-*/chrome-linux*/chrome' \
         -o -path '*/chromium_headless_shell-*/chrome-headless-shell' \) \
      2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "${candidate}" && -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  echo "Error: no Chromium-based browser found; install Google Chrome or set CHROME_BIN" >&2
  return 1
}

# Splice a fragment into the skeleton at the marker line and set the theme
# on <html>. getline keeps the fragment's bytes untouched, which sed/printf
# substitution would not.
wrap_panel() {
  local fragment="$1" theme="$2" out="$3"
  awk -v fragment="${fragment}" -v theme="${theme}" '
    /^<html / { sub(/data-theme="light"/, "data-theme=\"" theme "\"") }
    /^<!-- panel -->$/ {
      while ((getline line < fragment) > 0) print line
      close(fragment)
      next
    }
    { print }
  ' "${SKELETON}" > "${out}"
}

# 01-flow + light -> 01-flow, 01-flow + dark -> 01-flow.dark
output_stem() {
  local name="$1" theme="$2"
  if [[ "${theme}" == "dark" ]]; then
    echo "${name}.dark"
  else
    echo "${name}"
  fi
}

# True once the PNG ends in its IEND chunk and the DOM dump is complete.
# The chunk is read with head/tail rather than grep: BSD grep refuses to match
# inside the non-UTF-8 CRC bytes that follow the chunk name.
outputs_ready() {
  local png="$1" dom="$2"
  [[ -s "${png}" && -s "${dom}" ]] || return 1
  [[ "$(tail -c 8 "${png}" | head -c 4)" == "IEND" ]] || return 1
  grep -q '</html>' "${dom}"
}

# Chrome produces the screenshot and the DOM dump within a second or two and
# then, on some macOS builds, never exits. Waiting on the outputs rather than
# the process keeps a render at a few seconds either way; the browser is
# terminated once both exist.
render_one() {
  local html="$1" png="$2" dom="$3" log="$4"
  local pid deadline=$((SECONDS + RENDER_TIMEOUT))

  "${CHROME}" "${chrome_flags[@]}" --screenshot="${png}" --dump-dom "file://${html}" > "${dom}" 2> "${log}" &
  pid=$!

  while ! outputs_ready "${png}" "${dom}"; do
    if ! kill -0 "${pid}" 2>/dev/null; then
      wait "${pid}" 2>/dev/null || true
      outputs_ready "${png}" "${dom}" && return 0
      return 1
    fi
    if (( SECONDS >= deadline )); then
      kill -KILL "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
      return 1
    fi
    sleep 0.2
  done

  kill -TERM "${pid}" 2>/dev/null || true
  wait "${pid}" 2>/dev/null || true
  return 0
}

mkdir -p "${OUT_DIR}"

if [[ "${wrap_only}" -eq 1 ]]; then
  for fragment in "$@"; do
    name="$(basename -- "${fragment}" .html)"
    for theme in "${themes[@]}"; do
      stem="$(output_stem "${name}" "${theme}")"
      wrap_panel "${fragment}" "${theme}" "${OUT_DIR}/${stem}.html"
      echo "wrapped  ${OUT_DIR}/${stem}.html"
    done
  done
  exit 0
fi

CHROME="$(find_chrome)"
readonly CHROME

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# A private profile keeps headless runs independent of a Chrome that is
# already open, which would otherwise refuse to start a second instance.
chrome_flags=(
  --headless=new
  --disable-gpu
  --hide-scrollbars
  --no-first-run
  --no-default-browser-check
  --disable-extensions
  --disable-sync
  --user-data-dir="${WORK_DIR}/profile"
  --force-device-scale-factor="${SCALE}"
  --window-size="${CANVAS_W},${CANVAS_H}"
)
if [[ "$(id -u)" -eq 0 ]]; then
  chrome_flags+=(--no-sandbox)
fi

failures=0
total=0
for fragment in "$@"; do
  name="$(basename -- "${fragment}" .html)"
  for theme in "${themes[@]}"; do
    total=$((total + 1))
    stem="$(output_stem "${name}" "${theme}")"
    html="${WORK_DIR}/${stem}.html"
    dom="${WORK_DIR}/${stem}.dom"
    log="${WORK_DIR}/${stem}.log"
    png="${OUT_DIR}/${stem}.png"
    wrap_panel "${fragment}" "${theme}" "${html}"
    rm -f "${png}"

    # One launch does both: the DOM carries the overflow probe's result, the
    # screenshot is the deliverable.
    if ! render_one "${html}" "${png}" "${dom}" "${log}"; then
      echo "FAIL     ${stem}: no PNG and DOM within ${RENDER_TIMEOUT}s" >&2
      grep -v 'task_policy_set' "${log}" | sed 's/^/         /' >&2 || true
      rm -f "${png}"
      failures=$((failures + 1))
      continue
    fi

    # grep exits 1 on a panel that fits, which is the normal case, not an error.
    overflow="$(grep -o 'data-overflow="[^"]*"' "${dom}" | head -n 1 | sed 's/data-overflow="\(.*\)"/\1/' || true)"
    if [[ -n "${overflow}" ]]; then
      echo "OVERFLOW ${png}: ${overflow} (canvas ${CANVAS_W}x${CANVAS_H} exceeded, or scene content outside its viewBox); shorten, move, or split" >&2
      failures=$((failures + 1))
    else
      echo "ok       ${png}"
    fi
  done
done

if [[ "${failures}" -ne 0 ]]; then
  echo "${failures} of ${total} renders need attention" >&2
  exit 1
fi
