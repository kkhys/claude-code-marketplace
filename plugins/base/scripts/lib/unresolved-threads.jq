# Shape a reviewThreads connection (see review-threads.graphql) into the
# unresolved-thread list every PR skill consumes. One definition keeps the
# PENDING-draft filter and the deleted-user fallback identical between the
# babysitting-pr watcher and read-unresolved-pr-comments.sh.
#
# jq module: load with `jq -L <lib dir> 'include "unresolved-threads"; ...'`.
# Null-tolerant: a partial GraphQL response yields [] rather than an error.

def unresolved_threads:
  [ ((.nodes) // [])[]
    | select(.isResolved == false)
    | {
        thread_id: .id,
        path: .path,
        line: .line,
        start_line: .startLine,
        is_outdated: .isOutdated,
        comments: [ ((.comments.nodes) // [])[]
                    # Comments attached to a PENDING review are not published
                    # yet; acting on them would leak an unsent draft review.
                    | select((.pullRequestReview.state // "SUBMITTED") != "PENDING")
                    | {
                        author: (.author.login // "ghost"),
                        association: .authorAssociation,
                        body: .body,
                        url: .url,
                        created_at: .createdAt
                      } ]
      }
    | select((.comments | length) > 0) ];
