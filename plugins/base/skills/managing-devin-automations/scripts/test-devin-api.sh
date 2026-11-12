#!/usr/bin/env bash
set -euo pipefail

# Offline tests for devin-api.sh against a curl stub: URL building, where the
# token travels, body handling, error reporting, and cursor pagination.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/devin-api.sh"

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
  output="$(PATH="${WORK_DIR}/bin:${PATH}" DEVIN_API_KEY="${KEY-cog_secret}" \
    DEVIN_ORG_ID="${ORG-org-1}" XDG_CONFIG_HOME="${CONFIG-${WORK_DIR}/no-config}" \
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

reset 200 '{"items":[]}'
run GET /automations
check_that 'a GET prints the response body' test "${code}" -eq 0 -a "${output}" = '{"items":[]}'
check_that 'the path is appended to the organization URL' \
  argv_has 1 'https://api.devin.ai/v3/organizations/org-1/automations'
check_that 'the token travels on stdin' \
  grep -qF 'Authorization: Bearer cog_secret' "${STUB_DIR}/calls/1.stdin"
check_that 'the token stays out of argv' argv_lacks 1 'cog_secret'

printf '{"enabled":false}' > "${WORK_DIR}/body.json"
reset 200 '{"automation_id":"a1"}'
run PATCH /automations/a1 "${WORK_DIR}/body.json"
check_that 'a body file is sent as JSON' \
  argv_has 1 "@${WORK_DIR}/body.json"
check_that 'a body sets the content type' argv_has 1 'Content-Type: application/json'

reset 422 '{"title":"Unprocessable","errors":[{"loc":["triggers",0]}]}'
run POST /automations "${WORK_DIR}/body.json"
check_that 'a non-2xx exits 1 with the status and the problem body' \
  test "${code}" -eq 1 -a "${output}" != "${output/HTTP 422/}" -a "${output}" != "${output/\"errors\"/}"

reset 200 '{"items":[{"id":1}],"has_next_page":true,"end_cursor":"a/b="}' \
  200 '{"items":[{"id":2}],"has_next_page":false,"end_cursor":null}'
run --all GET /automations
check_that '--all merges every page into one array' \
  test "$(jq -c . <<< "${output}")" = '[{"id":1},{"id":2}]'
check_that '--all asks for the next page with the encoded cursor' \
  argv_has 2 'https://api.devin.ai/v3/organizations/org-1/automations?first=100&after=a%2Fb%3D'

reset 200 '{"items":[],"has_next_page":false}'
run --all GET '/automations?enabled=true'
check_that '--all extends an existing query string' \
  argv_has 1 'https://api.devin.ai/v3/organizations/org-1/automations?enabled=true&first=100'

reset 200 '{"items":[],"has_next_page":true,"end_cursor":null}'
run --all GET /automations
check_that 'a next page without a cursor fails instead of looping' \
  test "${code}" -eq 1 -a "${output}" != "${output/end_cursor is empty/}"

reset
run --all DELETE /automations/a1
check_that '--all is refused for a write' refused

reset
run TRACE /automations
check_that 'an unknown method is refused before any request' refused

reset
printf 'not json' > "${WORK_DIR}/bad.json"
run POST /automations "${WORK_DIR}/bad.json"
check_that 'an invalid body file is refused before any request' refused

reset
KEY='' run GET /automations
check_that 'a missing token is reported before any request' \
  test "${code}" -ne 0 -a "${output}" != "${output/DEVIN_API_KEY/}"
check_that 'a missing token makes no request' no_request

reset
ORG='' run GET /automations
check_that 'a missing organization id is reported' \
  test "${code}" -ne 0 -a "${output}" != "${output/DEVIN_ORG_ID/}"

mkdir -p "${WORK_DIR}/config/devin"
printf 'cog_from_file\n' > "${WORK_DIR}/config/devin/api_key"
printf '{"devin":{"org_id":"org-file"}}' > "${WORK_DIR}/config/devin/config.json"

reset 200 '{}'
KEY='' ORG='' CONFIG="${WORK_DIR}/config" run GET /automations
check_that 'the Devin CLI files supply the organization id' \
  argv_has 1 'https://api.devin.ai/v3/organizations/org-file/automations'
check_that 'the Devin CLI files supply the token, without its newline' \
  grep -qxF 'header = "Authorization: Bearer cog_from_file"' "${STUB_DIR}/calls/1.stdin"

reset 200 '{}'
CONFIG="${WORK_DIR}/config" run GET /automations
check_that 'the environment wins over the Devin CLI files' \
  argv_has 1 'https://api.devin.ai/v3/organizations/org-1/automations'

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
