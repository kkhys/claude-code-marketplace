#!/usr/bin/env bash
set -euo pipefail

# Fetch the current PR's unresolved review threads as structured JSON.
#
# The thread selection and mapping live in scripts/lib and are shared with the
# babysitting-pr watcher, so PENDING drafts are filtered, Bot/Team reviewers
# resolve to a name, and deleted users fall back to "ghost" in both places.

# Physical path on purpose: other agents reach this script through a
# ~/.agents/skills symlink, and ../../../scripts/lib only exists from the
# real location.
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
LIB_DIR="$(cd -- "${SCRIPT_DIR}/../../../scripts/lib" && pwd)"
readonly LIB_DIR

# shellcheck source=../../../scripts/lib/gh-context.sh disable=SC1091  # CI runs shellcheck without -x
source "${LIB_DIR}/gh-context.sh"
gh_context

# shellcheck disable=SC2016  # $owner/$repo/$prNumber are GraphQL variables, not shell ones
gh api graphql \
  -f owner="${OWNER}" \
  -f repo="${REPO}" \
  -F prNumber="${PR_NUMBER}" \
  -f query='
query($owner: String!, $repo: String!, $prNumber: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $prNumber) {
      number
      title
      url
      state
      author {
        login
      }
      '"$(cat "${LIB_DIR}/review-requests.graphql")"'
      '"$(cat "${LIB_DIR}/review-threads.graphql")"'
    }
  }
}' | jq -L "${LIB_DIR}" '
include "unresolved-threads";
.data.repository.pullRequest as $pr
| {
    pr_number: $pr.number,
    title: $pr.title,
    url: $pr.url,
    state: $pr.state,
    author: ($pr.author.login // "ghost"),
    requested_reviewers: [ (($pr.reviewRequests.nodes) // [])[]
                           | (.requestedReviewer.login // .requestedReviewer.slug)
                           | select(. != null) ],
    unresolved_threads: ($pr.reviewThreads | unresolved_threads)
  }'
