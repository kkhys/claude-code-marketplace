#!/usr/bin/env bash
set -euo pipefail

# Offline tests for qase-api.sh against a curl stub: URL building, where the
# token travels, body handling, error reporting, offset pagination, and the
# attachment upload with its checks before the request.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/qase-api.sh"

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# The stub answers call N with responses/N.json and responses/N.status, and
# records each call's argv and stdin under calls/.
mkdir -p "${WORK_DIR}/bin"
cat > "${WORK_DIR}/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
n=$(($(cat "${STUB_DIR}/count" 2>/dev/null || echo 0) + 1))
echo "${n}" > "${STUB_DIR}/count"
printf '%s\n' "$@" > "${STUB_DIR}/calls/${n}.argv"
cat > "${STUB_DIR}/calls/${n}.stdin"
out=''
while [[ $# -gt 0 ]]; do
  if [[ "$1" == '--output' ]]; then out="$2"; fi
  shift
done
cat "${STUB_DIR}/responses/${n}.json" > "${out}"
cat "${STUB_DIR}/responses/${n}.status"
STUB
chmod +x "${WORK_DIR}/bin/curl"

# reset <status> <body> [<status> <body> ...] queues the stub's responses.
reset() {
  STUB_DIR="$(mktemp -d "${WORK_DIR}/stub.XXXXXX")"
  export STUB_DIR
  mkdir -p "${STUB_DIR}/calls" "${STUB_DIR}/responses"
  local n=0
  while [[ $# -gt 0 ]]; do
    n=$((n + 1))
    printf '%s' "$1" > "${STUB_DIR}/responses/${n}.status"
    printf '%s' "$2" > "${STUB_DIR}/responses/${n}.json"
    shift 2
  done
}

run() {
  code=0
  output="$(PATH="${WORK_DIR}/bin:${PATH}" QASE_API_TOKEN="${TOKEN-qase_secret}" \
    bash "${SCRIPT}" "$@" 2>&1)" || code=$?
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

argv_has() { grep -qxF -- "$2" "${STUB_DIR}/calls/$1.argv"; }
argv_lacks() { ! grep -qF -- "$2" "${STUB_DIR}/calls/$1.argv"; }
no_request() { [[ ! -e "${STUB_DIR}/calls/1.argv" ]]; }
refused() { [[ "${code}" -eq 1 ]] && no_request; }

# page <count> prints a list response holding that many entities.
page() {
  jq -cn --argjson n "$1" '{status: true, result: {count: $n, entities: [range($n) | {id: .}]}}'
}

reset 200 '{"status":true,"result":{"id":7}}'
run GET /case/MS/7
check_that 'a GET prints the response body' \
  test "${code}" -eq 0 -a "${output}" = '{"status":true,"result":{"id":7}}'
check_that 'the path is appended to the v1 URL' argv_has 1 'https://api.qase.io/v1/case/MS/7'
check_that 'the token travels on stdin' \
  grep -qxF 'header = "Token: qase_secret"' "${STUB_DIR}/calls/1.stdin"
check_that 'the token stays out of argv' argv_lacks 1 'qase_secret'

printf '{"title":"Run"}' > "${WORK_DIR}/body.json"
reset 200 '{"status":true,"result":{"id":42}}'
run POST /run/MS "${WORK_DIR}/body.json"
check_that 'a body file is sent as JSON' argv_has 1 "@${WORK_DIR}/body.json"
check_that 'a body sets the content type' argv_has 1 'Content-Type: application/json'

reset 422 '{"status":false,"errorMessage":"Data is invalid.","errorFields":[{"field":"title"}]}'
run POST /run/MS "${WORK_DIR}/body.json"
check_that 'a non-2xx exits 1 with the status and the error body' \
  test "${code}" -eq 1 -a "${output}" != "${output/HTTP 422/}" -a "${output}" != "${output/errorFields/}"

reset 200 "$(page 100)" 200 "$(page 3)"
run --all GET '/case/MS?suite_id=3'
check_that '--all merges every page into one array' \
  test "$(jq 'length' <<< "${output}")" -eq 103
check_that '--all extends an existing query string' \
  argv_has 1 'https://api.qase.io/v1/case/MS?suite_id=3&limit=100&offset=0'
check_that '--all asks for the next page by offset' \
  argv_has 2 'https://api.qase.io/v1/case/MS?suite_id=3&limit=100&offset=100'

reset 200 "$(page 0)"
run --all GET /run/MS
check_that '--all on an empty list prints an empty array' \
  test "${code}" -eq 0 -a "$(jq -c . <<< "${output}")" = '[]'
check_that '--all starts a query string when the path has none' \
  argv_has 1 'https://api.qase.io/v1/run/MS?limit=100&offset=0'

reset 200 '{"status":true,"result":{"id":7}}'
run --all GET /case/MS/7
check_that '--all on a single record fails instead of printing nothing' \
  test "${code}" -eq 1 -a "${output}" != "${output/result.entities/}"

printf 'clip' > "${WORK_DIR}/case-12.mp4"
printf 'clip' > "${WORK_DIR}/a,b;c.mp4"
reset 200 '{"status":true,"result":[{"hash":"h1","filename":"case-12.mp4"}]}'
run upload MS "${WORK_DIR}/case-12.mp4" "${WORK_DIR}/a,b;c.mp4"
check_that 'upload prints the response with the hashes' \
  test "${code}" -eq 0 -a "$(jq -r '.result[0].hash' <<< "${output}")" = 'h1'
check_that 'upload posts to the project attachments' \
  argv_has 1 'https://api.qase.io/v1/attachment/MS'
check_that 'upload sends each file as a file[] part' \
  argv_has 1 "file[]=@\"${WORK_DIR}/case-12.mp4\""
check_that 'upload quotes a name curl would split' \
  argv_has 1 "file[]=@\"${WORK_DIR}/a,b;c.mp4\""
check_that 'upload sets no JSON content type' argv_lacks 1 'Content-Type: application/json'
check_that 'upload keeps the token on stdin' \
  grep -qxF 'header = "Token: qase_secret"' "${STUB_DIR}/calls/1.stdin"

reset
run upload MS "${WORK_DIR}/missing.mp4"
check_that 'upload refuses a missing file before any request' refused

reset
run upload MS
check_that 'upload refuses an empty file list' refused

reset
too_many=()
for _ in $(seq 1 21); do too_many+=("${WORK_DIR}/case-12.mp4"); done
run upload MS "${too_many[@]}"
check_that 'upload refuses more than 20 files' refused

reset
dd if=/dev/zero of="${WORK_DIR}/big.mp4" bs=1048576 count=33 2>/dev/null
run upload MS "${WORK_DIR}/big.mp4"
check_that 'upload refuses a file over 32 MB before any request' refused

reset
run upload '../MS' "${WORK_DIR}/case-12.mp4"
check_that 'upload refuses a project code that is not one' refused

reset
run --all POST /run/MS "${WORK_DIR}/body.json"
check_that '--all is refused for a write' refused

reset
run --all upload MS "${WORK_DIR}/case-12.mp4"
check_that '--all is refused for an upload' refused

reset
run TRACE /case/MS
check_that 'an unknown method is refused before any request' refused

reset
run GET case/MS
check_that 'a path without a leading slash is refused' refused

reset
run GET '/case/MS?search=two words'
check_that 'a path with whitespace is refused before curl rejects it' refused

reset
printf 'not json' > "${WORK_DIR}/bad.json"
run POST /run/MS "${WORK_DIR}/bad.json"
check_that 'an invalid body file is refused before any request' refused

reset
TOKEN='' run GET /case/MS
check_that 'a missing token is reported before any request' \
  test "${code}" -ne 0 -a "${output}" != "${output/QASE_API_TOKEN/}"
check_that 'a missing token makes no request' no_request

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
