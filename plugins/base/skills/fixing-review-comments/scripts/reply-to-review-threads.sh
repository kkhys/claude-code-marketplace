#!/usr/bin/env bash
set -euo pipefail

# Reply to GitHub PR review threads in bulk.
# Usage: reply-to-review-threads.sh <replies.json>
#
# Payload: { replies: [{ thread_id: string, body: string }] }
#
# Every reply is prefixed with an attribution marker (scripts/lib/attribution.jq)
# so reviewers can tell an agent's reply from the user's own. It is applied here
# rather than left to the caller so it cannot be forgotten.
#
# Exits non-zero when any reply failed to post, so a caller can tell a clean
# run from a partial one.

readonly PAYLOAD_FILE="${1:?Usage: reply-to-review-threads.sh <replies.json>}"

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

if [[ "$(jq '.replies | type' "${PAYLOAD_FILE}")" != '"array"' ]]; then
  echo "Error: Payload must contain a 'replies' array" >&2
  exit 1
fi

# Validate every entry before posting anything. A malformed body discovered
# mid-loop would abort under `set -e` after earlier replies already landed,
# leaving the threads half-answered with no record of where it stopped.
INVALID="$(jq '[.replies[]
  | select((.thread_id | type) != "string" or .thread_id == ""
           or (.body | type) != "string" or .body == "")] | length' "${PAYLOAD_FILE}")"
readonly INVALID

if [[ "${INVALID}" -ne 0 ]]; then
  echo "Error: ${INVALID} of $(jq '.replies | length' "${PAYLOAD_FILE}") replies lack a non-empty thread_id and body" >&2
  exit 1
fi

REPLY_COUNT="$(jq '.replies | length' "${PAYLOAD_FILE}")"
readonly REPLY_COUNT

if [[ "${REPLY_COUNT}" -eq 0 ]]; then
  echo "No replies to post."
  exit 0
fi

echo "Replying to ${REPLY_COUNT} thread(s)..."

success=0
failed=0

for i in $(seq 0 $(( REPLY_COUNT - 1 ))); do
  thread_id="$(jq -r ".replies[$i].thread_id" "${PAYLOAD_FILE}")"
  body="$(jq -r -L "${LIB_DIR}" --argjson i "${i}" \
    'include "attribution"; .replies[$i].body | attribute' \
    "${PAYLOAD_FILE}")"

  # Capture stderr only: the failure reason (already-resolved thread, rate
  # limit, bad ID) is the part the caller needs to act on.
  # shellcheck disable=SC2016  # $threadId/$body are GraphQL variables, not shell ones
  if reply_err="$(gh api graphql \
    -f query='
      mutation($threadId: ID!, $body: String!) {
        addPullRequestReviewThreadReply(
          input: { pullRequestReviewThreadId: $threadId, body: $body }
        ) {
          comment { id url }
        }
      }' \
    -f threadId="${thread_id}" \
    -f body="${body}" 2>&1 > /dev/null)"; then
    echo "Replied: ${thread_id}"
    (( success++ )) || true
  else
    echo "Failed:  ${thread_id}" >&2
    echo "  Error: ${reply_err}" >&2
    (( failed++ )) || true
  fi
done

echo "Done. ${success} replied, ${failed} failed."
[[ "${failed}" -eq 0 ]]
