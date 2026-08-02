#!/usr/bin/env bash
set -euo pipefail
set +H

readonly BASE_DIR="${HOME}/projects/github.com/kkhys/me/apps/memo/memo-content/memo"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

# ULID-like ID generator (26 characters, lowercase)
# Format: 10 chars timestamp + 16 chars random
# Character set: 0-9, a-v (base32-like)
generate_ulid() {
  local timestamp_ms="${1}"

  # Base32 character set (0-9, a-v)
  local charset="0123456789abcdefghjkmnpqrstvwxyz"

  # Generate timestamp part (10 characters)
  local ts_part=""
  local ts="${timestamp_ms}"
  for _ in {1..10}; do
    local idx=$((ts % 32))
    ts_part="${charset:idx:1}${ts_part}"
    ts=$((ts / 32))
  done

  # Generate random part (16 characters)
  local random_part=""
  for _ in {1..16}; do
    local rand_idx=$((RANDOM % 32))
    random_part="${random_part}${charset:rand_idx:1}"
  done

  echo "${ts_part}${random_part}"
}

# Format current datetime as "YYYY-MM-DD HH:MM:SS"
format_datetime() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Convert datetime string to directory name format "YYYYMMDD_HHMMSS"
datetime_to_dirname() {
  local datetime="${1}"
  echo "${datetime}" | sed 's/[- :]//g' | sed 's/\([0-9]\{8\}\)\([0-9]\{6\}\)/\1_\2/'
}

create_memo() {
  local dir_name="${1}"
  local ulid="${2}"
  local created_at="${3}"
  local tag="${4}"
  local comment="${5}"
  local content="${6}"

  local memo_dir="${BASE_DIR}/${dir_name}"
  local index_file="${memo_dir}/index.md"

  mkdir -p "${memo_dir}"

  # Remove leading newlines from content
  content="${content#"${content%%[![:space:]]*}"}"
  content="${content#$'\n'}"

  {
    echo "---"
    echo "id: ${ulid}"
    echo "createdAt: ${created_at}"
    [ -n "${tag}" ] && echo "tag: ${tag}"
    [ -n "${comment}" ] && echo "comment: ${comment}"
    echo "---"
    echo ""
    printf '%s\n' "${content}"
  } > "${index_file}"

  echo ""
  echo "Memo created successfully"
  echo "  Directory: ~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/${dir_name}/"
  echo "  File: index.md"
  echo "  ID: ${ulid}"
  echo "  Created: ${created_at}"
  [ -n "${tag}" ] && echo "  Tag: ${tag}"
  [ -n "${comment}" ] && echo "  Comment: ${comment}"
}

main() {
  local tag=""
  local comment=""

  while [ $# -gt 0 ]; do
    case "${1}" in
      --tag)
        tag="${2:-}"
        shift 2
        ;;
      --comment)
        comment="${2:-}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [ $# -eq 0 ]; then
    echo "" >&2
    echo "Error: Memo content is required" >&2
    echo "" >&2
    echo "Usage: ${SCRIPT_NAME} [--tag TAG] [--comment MEMO_ID] [memo content]" >&2
    echo "Example: ${SCRIPT_NAME} \"Your memo content here\"" >&2
    echo "Example: ${SCRIPT_NAME} --tag drink_log \"Your memo content here\"" >&2
    echo "Example: ${SCRIPT_NAME} --comment 01kybqps0g15hbv4byxa4h6bw6 \"Follow-up memo\"" >&2
    exit 1
  fi

  local content="${*}"

  local created_at
  created_at="$(format_datetime)"

  local timestamp_ms
  timestamp_ms="$(date +%s)000"

  local ulid
  ulid="$(generate_ulid "${timestamp_ms}")"

  local dir_name
  dir_name="$(datetime_to_dirname "${created_at}")"

  create_memo "${dir_name}" "${ulid}" "${created_at}" "${tag}" "${comment}" "${content}"
}

main "$@"
