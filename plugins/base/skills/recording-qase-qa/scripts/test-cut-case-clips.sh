#!/usr/bin/env bash
set -euo pipefail

# Offline tests for cut-case-clips.sh against an ffmpeg stub: the cut points
# and file name of each case, the output directory, and the marks files it
# refuses before cutting anything.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/cut-case-clips.sh"

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# The stub records each call's argv under calls/ and creates the output file,
# which is its last argument.
mkdir -p "${WORK_DIR}/bin"
cat > "${WORK_DIR}/bin/ffmpeg" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
n=$(($(cat "${STUB_DIR}/count" 2>/dev/null || echo 0) + 1))
echo "${n}" > "${STUB_DIR}/count"
printf '%s\n' "$@" > "${STUB_DIR}/calls/${n}.argv"
: > "${!#}"
STUB
chmod +x "${WORK_DIR}/bin/ffmpeg"

readonly VIDEO="${WORK_DIR}/qa.webm"
: > "${VIDEO}"

# reset [<mark line> ...] starts a fresh take directory with that marks file.
reset() {
  TAKE_DIR="$(mktemp -d "${WORK_DIR}/take.XXXXXX")"
  STUB_DIR="${TAKE_DIR}/stub"
  export STUB_DIR
  mkdir -p "${STUB_DIR}/calls"
  MARKS="${TAKE_DIR}/marks"
  if [[ $# -gt 0 ]]; then printf '%s\n' "$@" > "${MARKS}"; fi
}

run() {
  code=0
  output="$(PATH="${WORK_DIR}/bin:${PATH}" bash "${SCRIPT}" "$@" 2>&1)" || code=$?
}

check() {
  local label="$1" ok="$2"
  if [[ "${ok}" == true ]]; then
    printf 'ok   %s\n' "${label}"
    pass_count=$((pass_count + 1))
  else
    printf 'FAIL %s\n       exit %s: %s\n' "${label}" "${code}" "${output}" >&2
    fail_count=$((fail_count + 1))
  fi
}

# check_that <label> <command...> passes when the command succeeds.
check_that() {
  local label="$1" ok=false
  shift
  if "$@"; then ok=true; fi
  check "${label}" "${ok}"
}

# cut_is <call> <from> <to> <output>: that ffmpeg call cut that span to that file.
cut_is() {
  local argv="${STUB_DIR}/calls/$1.argv"
  [[ "$(grep -xA1 -- '-ss' "${argv}" | tail -1)" == "$2" ]] \
    && [[ "$(grep -xA1 -- '-to' "${argv}" | tail -1)" == "$3" ]] \
    && [[ "$(tail -1 "${argv}")" == "$4" ]]
}
argv_has() { grep -qxF -- "$2" "${STUB_DIR}/calls/$1.argv"; }
no_cut() { [[ ! -e "${STUB_DIR}/calls/1.argv" ]]; }
refused() { [[ "${code}" -eq 1 ]] && no_cut && [[ "${output}" == *"$1"* ]]; }

reset 'start 1794460286.61' '101 1794460287.52' '102 1794460299.08' 'end 1794460310.63'
run "${MARKS}" "${VIDEO}"
check_that 'two cases make two cuts' test "${code}" -eq 0 -a "$(cat "${STUB_DIR}/count")" -eq 2
check_that 'a case runs from its mark to the next, counted from start' \
  cut_is 1 0.91 12.47 "${TAKE_DIR}/case-101.mp4"
check_that 'the last case ends at the end mark' \
  cut_is 2 12.47 24.02 "${TAKE_DIR}/case-102.mp4"
check_that 'the cut reads the take' argv_has 1 "${VIDEO}"
check_that 'ffmpeg is kept off the rows on stdin' argv_has 1 '-nostdin'
check_that 'the clips are printed, one path per line' \
  test "${output}" = "${TAKE_DIR}/case-101.mp4"$'\n'"${TAKE_DIR}/case-102.mp4"

reset 'start 10' 'MS3-7 12.5' 'end 20'
mkdir "${TAKE_DIR}/clips"
run "${MARKS}" "${VIDEO}" "${TAKE_DIR}/clips"
check_that 'an output directory takes the clips' \
  cut_is 1 2.50 10.00 "${TAKE_DIR}/clips/case-MS3-7.mp4"

reset 'start 10' 'end 20'
run "${MARKS}" "${VIDEO}"
check_that 'a take without a case is refused' refused 'No case'

reset '101 10' '102 15' 'end 20'
run "${MARKS}" "${VIDEO}"
check_that 'a first mark other than start is refused' refused 'not start'

reset 'start 10' '101 12' '102 15'
run "${MARKS}" "${VIDEO}"
check_that 'a last mark other than end is refused' refused 'not end'

reset 'start 10' '101 12' 'end 20' '102 25'
run "${MARKS}" "${VIDEO}"
check_that 'a mark after end is refused' refused 'follows end'

reset 'start 10' '101 15' '102 12' 'end 20'
run "${MARKS}" "${VIDEO}"
check_that 'a clock that goes back is refused' refused 'does not advance'

reset 'start 10' '101 12' '101 15' 'end 20'
run "${MARKS}" "${VIDEO}"
check_that 'a repeated case is refused instead of overwriting its clip' refused 'repeats'

reset 'start 10' '../101 12' 'end 20'
run "${MARKS}" "${VIDEO}"
check_that 'a label that is not a file name is refused' refused 'expected'

reset 'start 10' '101' 'end 20'
run "${MARKS}" "${VIDEO}"
check_that 'a mark without a time is refused' refused 'expected'

reset
run "${TAKE_DIR}/marks" "${VIDEO}"
check_that 'a missing marks file is refused' refused 'marks file'

reset 'start 10' '101 12' 'end 20'
run "${MARKS}" "${TAKE_DIR}/missing.webm"
check_that 'a missing video is refused' refused 'video'

reset 'start 10' '101 12' 'end 20'
run "${MARKS}" "${VIDEO}" "${TAKE_DIR}/missing"
check_that 'a missing output directory is refused' refused 'Not a directory'

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
