#!/usr/bin/env bash
set -euo pipefail

# Reply to GitHub PR review threads in bulk.
# Usage: reply-to-review-threads.sh <replies.json>
#
# Payload: { replies: [{ thread_id: string, body: string }] }

readonly PAYLOAD_FILE="${1:?Usage: reply-to-review-threads.sh <replies.json>}"

if [[ ! -f "${PAYLOAD_FILE}" ]]; then
  echo "Error: Payload file not found: ${PAYLOAD_FILE}" >&2
  exit 1
fi

if ! jq empty "${PAYLOAD_FILE}" 2>/dev/null; then
  echo "Error: Invalid JSON in payload file" >&2
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
  body="$(jq -r ".replies[$i].body" "${PAYLOAD_FILE}")"

  # shellcheck disable=SC2016  # $threadId/$body are GraphQL variables, not shell ones
  if gh api graphql \
    -f query='
      mutation($threadId: ID!, $body: String!) {
        addPullRequestReviewThreadReply(
          input: { pullRequestReviewThreadId: $threadId, body: $body }
        ) {
          comment { id url }
        }
      }' \
    -f threadId="${thread_id}" \
    -f body="${body}" > /dev/null 2>&1; then
    echo "Replied: ${thread_id}"
    (( success++ )) || true
  else
    echo "Failed:  ${thread_id}" >&2
    (( failed++ )) || true
  fi
done

echo "Done. ${success} replied, ${failed} failed."
