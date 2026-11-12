#!/usr/bin/env bash
set -euo pipefail

# Call the Devin v3 organization API.
# Usage: devin-api.sh [--all] <METHOD> <path> [body.json]
#
# <path> is relative to /v3/organizations/$DEVIN_ORG_ID and may carry a query
# string: /automations, /automations/schemas, /playbooks/<id>.
# --all (GET only) follows the cursor and prints every item as one JSON array.
#
# Credentials come from DEVIN_API_KEY and DEVIN_ORG_ID, else from the Devin
# CLI's own files: ~/.config/devin/api_key and `devin.org_id` in config.json.
#
# A non-2xx response exits 1 with the status and the problem+json body on
# stderr; on a 422 that body's `errors` names the rejected fields.

readonly USAGE='Usage: devin-api.sh [--all] <METHOD> <path> [body.json]'
readonly API_BASE='https://api.devin.ai/v3/organizations'

all=false
if [[ "${1:-}" == '--all' ]]; then
  all=true
  shift
fi

readonly METHOD="${1:?${USAGE}}"
readonly API_PATH="${2:?${USAGE}}"
readonly BODY_FILE="${3:-}"

case "${METHOD}" in
  GET | POST | PATCH | PUT | DELETE) ;;
  *)
    echo "Error: Unsupported method: ${METHOD}" >&2
    exit 1
    ;;
esac

if [[ "${API_PATH}" != /* ]]; then
  echo "Error: Path must start with '/': ${API_PATH}" >&2
  exit 1
fi

if [[ "${all}" == true && "${METHOD}" != 'GET' ]]; then
  echo 'Error: --all only applies to GET' >&2
  exit 1
fi

if [[ -n "${BODY_FILE}" ]] && ! jq empty "${BODY_FILE}" 2>/dev/null; then
  echo "Error: Body file is missing or not valid JSON: ${BODY_FILE}" >&2
  exit 1
fi

readonly CLI_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/devin"
if [[ -z "${DEVIN_API_KEY:-}" && -r "${CLI_DIR}/api_key" ]]; then
  DEVIN_API_KEY="$(tr -d '[:space:]' < "${CLI_DIR}/api_key")"
fi
if [[ -z "${DEVIN_ORG_ID:-}" && -r "${CLI_DIR}/config.json" ]]; then
  DEVIN_ORG_ID="$(jq -r '.devin.org_id // empty' "${CLI_DIR}/config.json")"
fi
: "${DEVIN_API_KEY:?Set DEVIN_API_KEY to a cog_ token (Settings > Devin API), or log in with the Devin CLI}"
: "${DEVIN_ORG_ID:?Set DEVIN_ORG_ID to the org- id shown at the top of Settings > Devin API}"

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# Print the response body of one request, or fail with it on stderr.
request() {
  local url="$1" out="${WORK_DIR}/response" status
  local -a args=(
    --silent --show-error --max-time 60
    --request "${METHOD}"
    --output "${out}"
    --write-out '%{http_code}'
    --config -
  )
  if [[ -n "${BODY_FILE}" ]]; then
    args+=(--header 'Content-Type: application/json' --data-binary "@${BODY_FILE}")
  fi

  : > "${out}"
  # The token goes in through stdin so it never appears in the process list.
  status="$(printf 'header = "Authorization: Bearer %s"\n' "${DEVIN_API_KEY}" \
    | curl "${args[@]}" "${url}")"

  if [[ "${status}" != 2* ]]; then
    echo "Error: ${METHOD} ${API_PATH} returned HTTP ${status}" >&2
    cat "${out}" >&2
    echo >&2
    exit 1
  fi
  cat "${out}"
}

readonly URL="${API_BASE}/${DEVIN_ORG_ID}${API_PATH}"

if [[ "${all}" != true ]]; then
  request "${URL}"
  exit 0
fi

separator='?'
[[ "${API_PATH}" == *\?* ]] && separator='&'
readonly separator

pages="${WORK_DIR}/pages"
: > "${pages}"
cursor=''
while :; do
  page_url="${URL}${separator}first=100"
  if [[ -n "${cursor}" ]]; then
    page_url+="&after=$(jq -rn --arg c "${cursor}" '$c | @uri')"
  fi
  page="$(request "${page_url}")"
  jq -c '.items' <<< "${page}" >> "${pages}"
  [[ "$(jq -r '.has_next_page // false' <<< "${page}")" == 'true' ]] || break
  cursor="$(jq -r '.end_cursor // empty' <<< "${page}")"
  if [[ -z "${cursor}" ]]; then
    echo 'Error: has_next_page is true but end_cursor is empty' >&2
    exit 1
  fi
done
jq -s 'add' "${pages}"
