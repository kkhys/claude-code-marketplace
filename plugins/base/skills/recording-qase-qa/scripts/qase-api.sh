#!/usr/bin/env bash
set -euo pipefail

# Call the Qase TestOps v1 API.
# Usage: qase-api.sh [--all] <METHOD> <path> [body.json]
#        qase-api.sh upload <project code> <file>...
#
# <path> is relative to /v1 and may carry a query string: /case/MS?suite_id=3,
# /run/MS/42?include=cases, /result/MS/42/bulk.
# --all (GET only) follows limit/offset and prints every entity as one JSON
# array.
# upload sends the files as attachments of the project and prints the response,
# whose result[] carries each file's hash.
#
# The token comes from QASE_API_TOKEN.
#
# A non-2xx response exits 1 with the status and the body on stderr; its
# errorFields names the rejected fields.

readonly USAGE='Usage: qase-api.sh [--all] <METHOD> <path> [body.json] | qase-api.sh upload <project code> <file>...'
readonly API_BASE='https://api.qase.io/v1'
readonly PAGE_SIZE=100
readonly MAX_UPLOAD_FILES=20
readonly MAX_UPLOAD_BYTES=$((32 * 1024 * 1024))

all=false
if [[ "${1:-}" == '--all' ]]; then
  all=true
  shift
fi
readonly all

readonly METHOD="${1:?${USAGE}}"
shift

upload_files=()
body_file=''
case "${METHOD}" in
  upload)
    code="${1:?${USAGE}}"
    shift
    if [[ "${all}" == true ]]; then
      echo 'Error: --all only applies to GET' >&2
      exit 1
    fi
    if [[ ! "${code}" =~ ^[A-Za-z0-9]{2,10}$ ]]; then
      echo "Error: Not a project code: ${code}" >&2
      exit 1
    fi
    if [[ $# -lt 1 || $# -gt ${MAX_UPLOAD_FILES} ]]; then
      echo "Error: upload takes 1 to ${MAX_UPLOAD_FILES} files, got $#" >&2
      exit 1
    fi
    for file in "$@"; do
      if [[ ! -f "${file}" || ! -r "${file}" ]]; then
        echo "Error: Not a readable file: ${file}" >&2
        exit 1
      fi
      if [[ "$(wc -c < "${file}")" -gt ${MAX_UPLOAD_BYTES} ]]; then
        echo "Error: Over Qase's 32 MB per file: ${file}" >&2
        exit 1
      fi
    done
    upload_files=("$@")
    api_path="/attachment/${code}"
    ;;
  GET | POST | PATCH | PUT | DELETE)
    api_path="${1:?${USAGE}}"
    body_file="${2:-}"
    if [[ "${api_path}" != /* ]]; then
      echo "Error: Path must start with '/': ${api_path}" >&2
      exit 1
    fi
    if [[ "${api_path}" =~ [[:space:]] ]]; then
      echo "Error: Path has whitespace; percent-encode it: ${api_path}" >&2
      exit 1
    fi
    if [[ "${all}" == true && "${METHOD}" != 'GET' ]]; then
      echo 'Error: --all only applies to GET' >&2
      exit 1
    fi
    if [[ -n "${body_file}" ]] && ! jq empty "${body_file}" 2>/dev/null; then
      echo "Error: Body file is missing or not valid JSON: ${body_file}" >&2
      exit 1
    fi
    ;;
  *)
    echo "Error: Unsupported method: ${METHOD}" >&2
    exit 1
    ;;
esac
readonly api_path body_file

: "${QASE_API_TOKEN:?Set QASE_API_TOKEN to a Qase API token (app.qase.io > Settings > API tokens)}"

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# Print the response body of one request, or fail with it on stderr.
request() {
  local url="$1" out="${WORK_DIR}/response" status file
  local -a args=(
    --silent --show-error
    --output "${out}"
    --write-out '%{http_code}'
    --config -
  )
  if [[ "${METHOD}" == 'upload' ]]; then
    args+=(--max-time 600 --request POST)
    for file in "${upload_files[@]}"; do
      # Quoted, so a comma or semicolon in the name is not read as a curl option.
      args+=(--form "file[]=@\"${file}\"")
    done
  else
    args+=(--max-time 60 --request "${METHOD}")
    if [[ -n "${body_file}" ]]; then
      args+=(--header 'Content-Type: application/json' --data-binary "@${body_file}")
    fi
  fi

  : > "${out}"
  # The token goes in through stdin so it never appears in the process list.
  status="$(printf 'header = "Token: %s"\n' "${QASE_API_TOKEN}" \
    | curl "${args[@]}" "${url}")"

  if [[ "${status}" != 2* ]]; then
    echo "Error: ${METHOD} ${api_path} returned HTTP ${status}" >&2
    cat "${out}" >&2
    echo >&2
    exit 1
  fi
  cat "${out}"
}

readonly URL="${API_BASE}${api_path}"

if [[ "${all}" != true ]]; then
  request "${URL}"
  exit 0
fi

separator='?'
[[ "${api_path}" == *\?* ]] && separator='&'
readonly separator

pages="${WORK_DIR}/pages"
: > "${pages}"
offset=0
while :; do
  page="$(request "${URL}${separator}limit=${PAGE_SIZE}&offset=${offset}")"
  if ! jq -ce '.result.entities | arrays' <<< "${page}" >> "${pages}"; then
    echo "Error: --all needs a list response with result.entities: ${api_path}" >&2
    exit 1
  fi
  count="$(jq -r '.result.count // (.result.entities | length)' <<< "${page}")"
  [[ "${count}" -eq ${PAGE_SIZE} ]] || break
  offset=$((offset + PAGE_SIZE))
done
jq -s 'add' "${pages}"
