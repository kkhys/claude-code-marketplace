#!/usr/bin/env bash
set -euo pipefail

OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
readonly OWNER_REPO
readonly OWNER="${OWNER_REPO%%/*}"
readonly REPO="${OWNER_REPO##*/}"
PR_NUMBER="$(gh pr view --json number --jq '.number')"
readonly PR_NUMBER

# Fetch all unresolved thread IDs with pagination.
# shellcheck disable=SC2016  # $endCursor is a GraphQL variable, not a shell one
THREAD_IDS=$(gh api graphql --paginate -f query='
query($endCursor: String) {
  repository(owner: "'"${OWNER}"'", name: "'"${REPO}"'") {
    pullRequest(number: '"${PR_NUMBER}"') {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { id isResolved }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id')

if [ -z "${THREAD_IDS}" ]; then
  echo "No unresolved threads found."
  exit 0
fi

COUNT=$(echo "${THREAD_IDS}" | wc -l | tr -d ' ')
readonly COUNT
echo "Found ${COUNT} unresolved thread(s)."
echo ""

resolved=0
failed=0

while read -r thread_id; do
  # shellcheck disable=SC2016  # $threadId is a GraphQL variable, not a shell one
  if result=$(gh api graphql \
    -f query='mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread { id isResolved }
      }
    }' \
    -f threadId="${thread_id}" 2>&1); then
    echo "Resolved: ${thread_id}"
    resolved=$((resolved + 1))
  else
    echo "Failed:   ${thread_id}"
    echo "  Error: ${result}"
    failed=$((failed + 1))
  fi
done <<< "${THREAD_IDS}"

echo ""
echo "Summary: ${resolved} resolved, ${failed} failed (out of ${COUNT} total)"
