#!/usr/bin/env bash
set -euo pipefail

# Tests for render-panels.sh.
#
# Argument handling and --wrap-only run everywhere. The browser cases run only
# where a Chromium is found (the script's own lookup decides), so a machine
# without one still passes while a machine with one checks the real output:
# PNG dimensions, both themes, and the overflow gate.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/render-panels.sh"

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

ok() {
  printf 'ok   %s\n' "$1"
  pass_count=$((pass_count + 1))
}

fail() {
  printf 'FAIL %s\n       %s\n' "$1" "$2" >&2
  fail_count=$((fail_count + 1))
}

# Assert the script's exit code and that its output mentions `expect_output`.
expect_result() {
  local label="$1" expect_code="$2" expect_output="$3"
  shift 3
  local output code=0
  output="$(bash "${SCRIPT}" "$@" 2>&1)" || code=$?
  if [[ "${code}" -eq "${expect_code}" && "${output}" == *"${expect_output}"* ]]; then
    ok "${label}"
  else
    fail "${label}" "expected: exit ${expect_code} containing $(printf '%q' "${expect_output}"); actual: exit ${code}: ${output}"
  fi
}

png_dims() {
  python3 -c 'import struct, sys
with open(sys.argv[1], "rb") as f:
    head = f.read(24)
print("%dx%d" % struct.unpack(">II", head[16:24]))' "$1" 2>&1 || true
}

readonly PANELS="${WORK_DIR}/panels"
readonly OUT="${WORK_DIR}/out"
mkdir -p "${PANELS}"

cat > "${PANELS}/01-fits.html" <<'EOF'
<h1>Fits the canvas<small>A single row of boxes</small></h1>
<div class="row fill center">
  <div class="box old">before</div>
  <div class="arrow">call</div>
  <div class="box new"><code>after()</code></div>
</div>
<div class="caption"><span><code>src/a.ts:1</code></span></div>
EOF

cat > "${PANELS}/02-overflows.html" <<'EOF'
<h1>Overflows the canvas</h1>
<ol class="steps">
<li>1</li><li>2</li><li>3</li><li>4</li><li>5</li><li>6</li><li>7</li><li>8</li><li>9</li><li>10</li><li>11</li><li>12</li>
</ol>
EOF

expect_result 'no arguments print usage' 1 'Usage:'
expect_result 'an output dir alone prints usage' 1 'Usage:' "${OUT}"
expect_result 'an unknown theme prints usage' 1 'Usage:' --theme sepia "${OUT}" "${PANELS}/01-fits.html"
expect_result 'a missing panel is rejected before rendering' 1 'panel not found' \
  "${OUT}" "${PANELS}/01-fits.html" "${PANELS}/missing.html"

expect_result '--wrap-only writes the wrapped HTML for both themes' 0 "wrapped  ${OUT}/01-fits.dark.html" \
  --wrap-only "${OUT}" "${PANELS}/01-fits.html"
if grep -qF '<div class="box old">before</div>' "${OUT}/01-fits.html" \
  && grep -qF '<main class="canvas">' "${OUT}/01-fits.html" \
  && ! grep -qF '<!-- panel -->' "${OUT}/01-fits.html"; then
  ok 'the fragment replaces the marker inside the canvas'
else
  fail 'the fragment replaces the marker inside the canvas' "$(grep -n -F -e 'box old' -e 'canvas' -e 'panel -->' "${OUT}/01-fits.html")"
fi
if grep -qF '<html lang="ja" data-theme="light">' "${OUT}/01-fits.html" \
  && grep -qF '<html lang="ja" data-theme="dark">' "${OUT}/01-fits.dark.html"; then
  ok 'each wrapped file carries its theme on <html>'
else
  fail 'each wrapped file carries its theme on <html>' "$(grep -h '<html' "${OUT}/01-fits.html" "${OUT}/01-fits.dark.html")"
fi

rm -rf "${OUT}"
expect_result '--theme light wraps only the light file' 0 "wrapped  ${OUT}/01-fits.html" \
  --wrap-only --theme light "${OUT}" "${PANELS}/01-fits.html"
if [[ ! -e "${OUT}/01-fits.dark.html" ]]; then
  ok '--theme light writes no dark file'
else
  fail '--theme light writes no dark file' 'dark file present'
fi

# Browser cases. The script's own lookup decides whether one exists.
rm -rf "${OUT}"
probe_output="$(bash "${SCRIPT}" "${OUT}" "${PANELS}/01-fits.html" 2>&1)" && probe_code=0 || probe_code=$?
if [[ "${probe_code}" -ne 0 && "${probe_output}" == *"no Chromium-based browser found"* ]]; then
  echo "skip browser cases: no Chromium found (set CHROME_BIN to run them)"
else
  if [[ "${probe_code}" -eq 0 && "${probe_output}" == *"ok       ${OUT}/01-fits.png"* && "${probe_output}" == *"ok       ${OUT}/01-fits.dark.png"* ]]; then
    ok 'a fitting panel renders in both themes'
  else
    fail 'a fitting panel renders in both themes' "exit ${probe_code}: ${probe_output}"
  fi

  if [[ "$(png_dims "${OUT}/01-fits.png")" == "3200x1800" && "$(png_dims "${OUT}/01-fits.dark.png")" == "3200x1800" ]]; then
    ok 'both PNGs are the 1600x900 canvas at device scale 2'
  else
    fail 'both PNGs are the 1600x900 canvas at device scale 2' "light $(png_dims "${OUT}/01-fits.png"), dark $(png_dims "${OUT}/01-fits.dark.png")"
  fi

  expect_result 'an overflowing panel fails the run' 1 "OVERFLOW ${OUT}/02-overflows.png" \
    --theme light "${OUT}" "${PANELS}/01-fits.html" "${PANELS}/02-overflows.html"
  if [[ -s "${OUT}/02-overflows.png" ]]; then
    ok 'the overflowing PNG is still written for inspection'
  else
    fail 'the overflowing PNG is still written for inspection' 'no file'
  fi
fi

printf '\n%d passed, %d failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
