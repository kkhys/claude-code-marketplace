#!/usr/bin/env bash
set -euo pipefail

# Post a PENDING review to a GitHub PR.
# Usage: post-pr-review.sh <payload.json>
#
# Payload: { body: string, comments: [{ path, line, body, side?, start_line?, start_side? }] }
# Review is always created in PENDING state (event field is intentionally omitted).
#
# The review summary and every comment are prefixed with an attribution marker so
# the PR author can tell agent-authored feedback from a human reviewer's. It is
# applied here rather than left to the caller so it cannot be forgotten.

readonly PAYLOAD_FILE="${1:?Usage: post-pr-review.sh <payload.json>}"
readonly MARKER="[from Claude Code]"

if [[ ! -f "${PAYLOAD_FILE}" ]]; then
  echo "Error: Payload file not found: ${PAYLOAD_FILE}" >&2
  exit 1
fi

if ! jq empty "${PAYLOAD_FILE}" 2>/dev/null; then
  echo "Error: Invalid JSON in payload file" >&2
  exit 1
fi

COMMENT_COUNT="$(jq '.comments | length' "${PAYLOAD_FILE}")"
readonly COMMENT_COUNT

# Get PR context
OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
readonly OWNER_REPO
readonly OWNER="${OWNER_REPO%%/*}"
readonly REPO="${OWNER_REPO##*/}"
PR_JSON="$(gh pr view --json number,url,headRefOid)"
readonly PR_JSON
PR_NUMBER="$(echo "${PR_JSON}" | jq -r '.number')"
readonly PR_NUMBER
PR_URL="$(echo "${PR_JSON}" | jq -r '.url')"
readonly PR_URL
HEAD_OID="$(echo "${PR_JSON}" | jq -r '.headRefOid')"
readonly HEAD_OID

# Build API request body (event omitted = PENDING)
# shellcheck disable=SC2016  # $commit_id/$marker are jq variables, not shell ones
REQUEST_BODY="$(jq --arg commit_id "${HEAD_OID}" --arg marker "${MARKER}" '
def attribute:
  if . == null or . == "" then $marker
  elif startswith($marker) then .
  else "\($marker) \(.)" end;
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
# masked by readonly's own exit status.
if ! RESPONSE="$(gh api \
  "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  --method POST \
  --input - <<< "${REQUEST_BODY}" 2>&1)"; then
  echo "Error: Failed to create review" >&2
  echo "${RESPONSE}" >&2
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
