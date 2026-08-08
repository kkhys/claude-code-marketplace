#!/usr/bin/env bash
set -euo pipefail

# Post a PENDING review to a GitHub PR.
# Usage: post-pr-review.sh <payload.json>
#
# Payload: { body: string, comments: [{ path, line, body, side?, start_line?, start_side? }] }
# Review is always created in PENDING state (event field is intentionally omitted).
#
# The review summary and every comment are prefixed with an attribution marker
# (scripts/lib/attribution.jq) so the PR author can tell agent-authored feedback
# from a human reviewer's. It is applied here rather than left to the caller so
# it cannot be forgotten.

readonly PAYLOAD_FILE="${1:?Usage: post-pr-review.sh <payload.json>}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_DIR="$(cd -- "${SCRIPT_DIR}/../../../scripts/lib" && pwd)"
readonly LIB_DIR

if [[ ! -f "${PAYLOAD_FILE}" ]]; then
  echo "Error: Payload file not found: ${PAYLOAD_FILE}" >&2
  exit 1
fi

if ! jq empty "${PAYLOAD_FILE}" 2>/dev/null; then
  echo "Error: Invalid JSON in payload file" >&2
  exit 1
fi

if [[ "$(jq '.comments | type' "${PAYLOAD_FILE}")" != '"array"' ]]; then
  echo "Error: Payload must contain a 'comments' array" >&2
  exit 1
fi

# Validate every comment before posting: GitHub rejects the whole review on a
# single malformed entry, and its API error does not say which one.
INVALID="$(jq '[.comments[]
  | select((.path | type) != "string" or .path == ""
           or (.line | type) != "number"
           or (.body | type) != "string" or .body == "")] | length' "${PAYLOAD_FILE}")"
readonly INVALID

if [[ "${INVALID}" -ne 0 ]]; then
  echo "Error: ${INVALID} of $(jq '.comments | length' "${PAYLOAD_FILE}") comments lack a non-empty path, numeric line, and non-empty body" >&2
  exit 1
fi

COMMENT_COUNT="$(jq '.comments | length' "${PAYLOAD_FILE}")"
readonly COMMENT_COUNT

# shellcheck source=../../../scripts/lib/gh-context.sh disable=SC1091  # CI runs shellcheck without -x
source "${LIB_DIR}/gh-context.sh"
gh_context

# Build API request body (event omitted = PENDING)
# shellcheck disable=SC2016  # $commit_id is a jq variable, not a shell one
REQUEST_BODY="$(jq -L "${LIB_DIR}" --arg commit_id "${HEAD_OID}" '
include "attribution";
{
  commit_id: $commit_id,
  body: (.body | attribute),
  comments: [.comments[] | {
    path: .path,
    line: .line,
    side: (.side // "RIGHT"),
    body: (.body | attribute)
  } + (if .start_line then {start_line: .start_line, start_side: (.start_side // "RIGHT")} else {} end)]
}' "${PAYLOAD_FILE}")"
readonly REQUEST_BODY

# Create PENDING review via REST API.
# Assignment and declaration are kept separate so that a gh failure is not
# masked by readonly's own exit status. Only stdout is captured — gh's stderr
# (including its error message) passes through to the caller.
if ! RESPONSE="$(gh api \
  "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  --method POST \
  --input - <<< "${REQUEST_BODY}")"; then
  echo "Error: Failed to create review" >&2
  if [[ -n "${RESPONSE}" ]]; then
    echo "${RESPONSE}" >&2
  fi
  exit 1
fi
readonly RESPONSE

REVIEW_ID="$(echo "${RESPONSE}" | jq -r '.id')"
readonly REVIEW_ID

echo "PENDING review created successfully."
echo "  Review ID: ${REVIEW_ID}"
echo "  Comments: ${COMMENT_COUNT}"
echo "  PR: ${PR_URL}"
echo "  Commit: ${HEAD_OID:0:7}"
