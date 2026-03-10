#!/usr/bin/env bash
set -euo pipefail

readonly OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
readonly OWNER="${OWNER_REPO%%/*}"
readonly REPO="${OWNER_REPO##*/}"
readonly PR_NUMBER="$(gh pr view --json number --jq '.number')"

# Fetch all unresolved thread IDs (auto-paginated)
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

if [ -z "$THREAD_IDS" ]; then
  echo "No unresolved threads to resolve."
  exit 0
fi

COUNT=$(echo "$THREAD_IDS" | wc -l | tr -d ' ')
echo "Found ${COUNT} unresolved thread(s)."

echo "$THREAD_IDS" | while read -r thread_id; do
  if gh api graphql \
    -f query='mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread { id isResolved }
      }
    }' \
    -f threadId="$thread_id" > /dev/null 2>&1; then
    echo "Resolved: $thread_id"
  else
    echo "Failed:   $thread_id"
  fi
done

echo "Done. All unresolved threads have been processed."
