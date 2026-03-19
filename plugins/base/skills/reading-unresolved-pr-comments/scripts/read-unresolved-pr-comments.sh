#!/usr/bin/env bash
set -euo pipefail

readonly OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
readonly OWNER="${OWNER_REPO%%/*}"
readonly REPO="${OWNER_REPO##*/}"
readonly PR_NUMBER="$(gh pr view --json number --jq '.number')"

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
      reviewRequests(first: 100) {
        nodes {
          requestedReviewer {
            ... on User {
              login
            }
          }
        }
      }
      reviewThreads(first: 100) {
        edges {
          node {
            id
            isResolved
            isOutdated
            path
            line
            startLine
            comments(last: 100) {
              nodes {
                author {
                  login
                }
                body
                url
                createdAt
              }
            }
          }
        }
      }
    }
  }
}' | jq '{
  pr_number: .data.repository.pullRequest.number,
  title: .data.repository.pullRequest.title,
  url: .data.repository.pullRequest.url,
  state: .data.repository.pullRequest.state,
  author: .data.repository.pullRequest.author.login,
  requested_reviewers: [.data.repository.pullRequest.reviewRequests.nodes[].requestedReviewer.login],
  unresolved_threads: [
    .data.repository.pullRequest.reviewThreads.edges[] |
    select(.node.isResolved == false) |
    {
      thread_id: .node.id,
      path: .node.path,
      line: .node.line,
      start_line: .node.startLine,
      is_outdated: .node.isOutdated,
      comments: [
        .node.comments.nodes[] |
        {
          author: .author.login,
          body: .body,
          url: .url,
          created_at: .createdAt
        }
      ]
    }
  ]
}'
