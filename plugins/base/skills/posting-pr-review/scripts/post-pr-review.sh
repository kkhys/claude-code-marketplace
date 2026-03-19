#!/usr/bin/env bash
set -euo pipefail

# Post a PENDING review to a GitHub PR.
# Usage: post-pr-review.sh <payload.json>
#
# Payload: { body: string, comments: [{ path, line, body, side?, start_line?, start_side? }] }
# Review is always created in PENDING state (event field is intentionally omitted).

readonly PAYLOAD_FILE="${1:?Usage: post-pr-review.sh <payload.json>}"

if [[ ! -f "${PAYLOAD_FILE}" ]]; then
  echo "Error: Payload file not found: ${PAYLOAD_FILE}" >&2
  exit 1
fi

if ! jq empty "${PAYLOAD_FILE}" 2>/dev/null; then
  echo "Error: Invalid JSON in payload file" >&2
  exit 1
fi

readonly COMMENT_COUNT="$(jq '.comments | length' "${PAYLOAD_FILE}")"

# Get PR context
readonly OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
readonly OWNER="${OWNER_REPO%%/*}"
readonly REPO="${OWNER_REPO##*/}"
readonly PR_JSON="$(gh pr view --json number,url,headRefOid)"
readonly PR_NUMBER="$(echo "${PR_JSON}" | jq -r '.number')"
readonly PR_URL="$(echo "${PR_JSON}" | jq -r '.url')"
readonly HEAD_OID="$(echo "${PR_JSON}" | jq -r '.headRefOid')"

# Build API request body (event omitted = PENDING)
readonly REQUEST_BODY="$(jq --arg commit_id "${HEAD_OID}" '{
  commit_id: $commit_id,
  body: (.body // ""),
  comments: [.comments[] | {
    path: .path,
    line: .line,
    side: (.side // "RIGHT"),
    body: .body
  } + (if .start_line then {start_line: .start_line, start_side: (.start_side // "RIGHT")} else {} end)]
}' "${PAYLOAD_FILE}")"

# Create PENDING review via REST API
readonly RESPONSE="$(gh api \
  "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  --method POST \
  --input - <<< "${REQUEST_BODY}" 2>&1)" || {
  echo "Error: Failed to create review" >&2
  echo "${RESPONSE}" >&2
  exit 1
}

readonly REVIEW_ID="$(echo "${RESPONSE}" | jq -r '.id')"

echo "PENDING review created successfully."
echo "  Review ID: ${REVIEW_ID}"
echo "  Comments: ${COMMENT_COUNT}"
echo "  PR: ${PR_URL}"
echo "  Commit: ${HEAD_OID:0:7}"
