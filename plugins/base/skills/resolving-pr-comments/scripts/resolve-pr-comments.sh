#!/usr/bin/env bash
set -euo pipefail

# Resolve GitHub PR review threads.
# Usage: resolve-pr-comments.sh [thread-id ...]
#
# With thread IDs, only those threads are resolved — this is how an automated
# workflow resolves exactly the threads it addressed without touching ones it
# deliberately left open. With no arguments, every unresolved thread on the
# current branch's PR is resolved.
#
# Exits non-zero when any thread failed to resolve, so a caller can tell a
# clean run from a partial one.

# Physical path on purpose: other agents reach this script through a
# ~/.agents/skills symlink, and ../../../scripts/lib only exists from the
# real location.
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
LIB_DIR="$(cd -- "${SCRIPT_DIR}/../../../scripts/lib" && pwd)"
readonly LIB_DIR

if [[ "$#" -gt 0 ]]; then
  THREAD_IDS="$(printf '%s\n' "$@")"
else
  # shellcheck source=../../../scripts/lib/gh-context.sh disable=SC1091  # CI runs shellcheck without -x
  source "${LIB_DIR}/gh-context.sh"
  gh_context

  # Fetch all unresolved thread IDs with pagination.
  # shellcheck disable=SC2016  # $owner/$repo/$prNumber/$endCursor are GraphQL variables, not shell ones
  THREAD_IDS=$(gh api graphql --paginate \
    -f owner="${OWNER}" \
    -f repo="${REPO}" \
    -F prNumber="${PR_NUMBER}" \
    -f query='
query($owner: String!, $repo: String!, $prNumber: Int!, $endCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $prNumber) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { id isResolved }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id')
fi

if [[ -z "${THREAD_IDS}" ]]; then
  echo "No unresolved threads found."
  exit 0
fi

COUNT=$(echo "${THREAD_IDS}" | wc -l | tr -d ' ')
readonly COUNT
echo "Found ${COUNT} unresolved thread(s)."
echo ""

resolved=0
failed=0

while IFS= read -r thread_id; do
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
    echo "Failed:   ${thread_id}" >&2
    echo "  Error: ${result}" >&2
    failed=$((failed + 1))
  fi
done <<< "${THREAD_IDS}"

echo ""
echo "Summary: ${resolved} resolved, ${failed} failed (out of ${COUNT} total)"
[[ "${failed}" -eq 0 ]]
