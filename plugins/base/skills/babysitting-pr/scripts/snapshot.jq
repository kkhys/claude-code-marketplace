include "unresolved-threads";

def check_bucket:
  if .__typename == "CheckRun" then
    if .status != "COMPLETED" then "pending"
    elif .conclusion == "SUCCESS" or .conclusion == "NEUTRAL" then "pass"
    elif .conclusion == "SKIPPED" then "skipped"
    else "fail" end
  else
    if .state == "SUCCESS" then "pass"
    elif .state == "PENDING" or .state == "EXPECTED" then "pending"
    else "fail" end
  end;

# Matches the Copilot code review bot only. A prefix match on "copilot" would
# also catch copilot-swe-agent[bot], which authors PRs rather than reviews them.
def is_copilot:
  ((. // "") | ascii_downcase | rtrimstr("[bot]")) as $login
  | $login == "copilot" or ($login | startswith("copilot-pull-request-reviewer"));

$raw.data.repository.pullRequest as $pr
| ($pr.headRefOid // "") as $head
| (($pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes) // []) as $ctxs
| [ $ctxs[]
    | {
        name: (.name // .context // "unknown"),
        bucket: check_bucket,
        conclusion: (.conclusion // .state),
        workflow: (.checkSuite.workflowRun.workflow.name // null),
        run_id: (.checkSuite.workflowRun.databaseId // null),
        url: (.detailsUrl // .targetUrl)
      } ] as $checks
# Thread selection lives in scripts/lib/unresolved-threads.jq, shared with
# read-unresolved-pr-comments.sh (PENDING-draft filter included).
| ($pr.reviewThreads | unresolved_threads) as $threads
| [ (($pr.reviews.nodes) // [])[]
    | select(.state != "PENDING")
    | {
        author: (.author.login // "ghost"),
        state: .state,
        commit: (.commit.oid // null),
        submitted_at: .submittedAt
      } ] as $reviews
| [ $pr.reviewRequests.nodes[]?
    | (.requestedReviewer.login // .requestedReviewer.slug // "") ] as $requested
| ([ $reviews[] | select(.author | is_copilot) ] | last) as $copilot_review
| ([ $requested[] | select(is_copilot) ] | length > 0) as $copilot_requested
| [ $threads[]
    | select([ .comments[].author | select(is_copilot) ] | length > 0) ] as $copilot_threads
| {
    passed: ([ $checks[] | select(.bucket == "pass") ] | length),
    failed: ([ $checks[] | select(.bucket == "fail") ] | length),
    pending: ([ $checks[] | select(.bucket == "pending") ] | length),
    skipped: ([ $checks[] | select(.bucket == "skipped") ] | length)
  } as $counts
| {
    polled_at: $now,
    timed_out: false,
    pr: {
      number: $pr.number,
      url: $pr.url,
      title: $pr.title,
      state: $pr.state,
      is_draft: $pr.isDraft,
      author: ($pr.author.login // null),
      base_ref: $pr.baseRefName,
      head_ref: $pr.headRefName,
      head_sha: $head,
      mergeable: $pr.mergeable,
      merge_state_status: $pr.mergeStateStatus,
      review_decision: ($pr.reviewDecision // null)
    },
    ci: ($counts + {
      total: ($checks | length),
      is_green: ($counts.failed == 0 and $counts.pending == 0),
      is_terminal: ($counts.pending == 0),
      # Only the names of what is still running: enough for a heartbeat, without
      # repeating every passing check on every poll.
      pending_checks: [ $checks[] | select(.bucket == "pending") | .name ],
      failed_checks: [ $checks[] | select(.bucket == "fail") ],
      failed_run_ids: ([ $checks[]
                         | select(.bucket == "fail")
                         | .run_id
                         | select(. != null) ] | unique)
    }),
    reviews: {
      unresolved_thread_count: ($threads | length),
      threads: $threads,
      # Who has weighed in and how, for the final summary only — the loop reads
      # pr.review_decision for the verdict and copilot.* for Copilot's round, so
      # carrying each review's commit and timestamp would be dead weight on
      # every poll.
      submitted: [ $reviews | group_by(.author)[] | last | {author, state} ],
      requested_reviewers: $requested
    },
    copilot: {
      participant: ($copilot_requested or ($copilot_review != null)),
      review_pending: $copilot_requested,
      last_review_commit: ($copilot_review.commit // null),
      reviewed_head_sha: (($copilot_review.commit // "") == $head),
      unresolved_thread_count: ($copilot_threads | length),
      unresolved_thread_ids: [ $copilot_threads[].thread_id ],
      rounds_used: ($prior.copilot_rounds // 0),
      rounds_cap: $cap,
      # How long the current request has been outstanding. Null when nothing is
      # pending, or when the request predates this field in the state file.
      request_age_seconds: (if $copilot_requested and ($prior.copilot_requested_at // null) != null
                            then $now_epoch - $prior.copilot_requested_at
                            else null end),
      stall_after_seconds: $stall
    },
    retries: {
      used: ($prior.retries[$head] // 0),
      budget: $budget
    },
    local: ($local + {
      on_head_branch: ($local.current_branch == $pr.headRefName),
      head_sha_matches: ($local.head_sha == $head)
    }),
    fingerprint: {
      state: $pr.state,
      is_draft: $pr.isDraft,
      head_sha: $head,
      mergeable: $pr.mergeable,
      merge_state_status: $pr.mergeStateStatus,
      review_decision: ($pr.reviewDecision // null),
      ci_counts: $counts,
      checks: ([ $checks[] | .name + "=" + .bucket ] | sort),
      threads: ([ $threads[] | .thread_id + ":" + (.comments | length | tostring) ] | sort),
      copilot_review_commit: ($copilot_review.commit // null),
      copilot_requested: $copilot_requested
    }
  }
| . as $s
| ($s.ci.is_green) as $green
| ($s.reviews.unresolved_thread_count == 0) as $review_clean
| (($s.copilot.participant | not)
   or ($s.copilot.reviewed_head_sha and $s.copilot.unresolved_thread_count == 0)) as $copilot_clean
| ($s.pr.mergeable == "CONFLICTING" or $s.pr.merge_state_status == "DIRTY") as $conflicting
| ($s.pr.merge_state_status == "BEHIND") as $behind
| (if $s.pr.state == "MERGED" then "merged"
   elif $s.pr.state == "CLOSED" then "closed"
   elif $s.pr.is_draft then
     (if ($green and $review_clean and $copilot_clean and ($conflicting | not))
      then "draft_review_clean" else null end)
   else
     # Approval is deliberately not required: BLOCKED with green CI and no open
     # threads means "waiting for a human to approve", which is the hand-off
     # point, not a failure.
     (if ($green and $review_clean and $copilot_clean
          and ($conflicting | not) and ($behind | not)
          and $s.pr.mergeable == "MERGEABLE"
          and (["CLEAN", "UNSTABLE", "BLOCKED", "HAS_HOOKS"] | index($s.pr.merge_state_status)))
      then "mergeable" else null end)
   end) as $terminal
| ([]
   + (if $conflicting then ["merge_conflict"] else [] end)
   + (if ($s.ci.failed > 0 and $s.ci.pending == 0 and $s.retries.used >= $s.retries.budget)
      then ["retry_budget_exhausted"] else [] end)
   + (if (($copilot_clean | not) and $s.copilot.rounds_used >= $s.copilot.rounds_cap)
      then ["copilot_round_cap"] else [] end)
   # A request that never produces a review leaves nothing for the watcher to
   # detect, so without this it would poll until the user gave up. The round cap
   # counts requests, not elapsed silence, and cannot catch it.
   + (if (($s.copilot.request_age_seconds // 0) > $stall)
      then ["copilot_review_stalled"] else [] end)) as $blockers
| (if $terminal == "merged" then ["stop_pr_merged"]
   elif $terminal == "closed" then ["stop_pr_closed"]
   else
     ([]
      + (if $s.reviews.unresolved_thread_count > 0 then ["process_review_comment"] else [] end)
      + (if $s.ci.failed > 0 then ["diagnose_ci_failure"] else [] end)
      + (if ($s.ci.failed > 0 and $s.ci.pending == 0 and $s.retries.used < $s.retries.budget)
         then ["retry_failed_checks"] else [] end)
      + (if $conflicting then ["resolve_merge_conflict"] else [] end)
      + (if $behind then ["update_branch"] else [] end)
      + (if ($s.copilot.participant
             and ($s.copilot.review_pending | not)
             and ($s.copilot.reviewed_head_sha | not)
             and $s.copilot.rounds_used < $s.copilot.rounds_cap)
         then ["request_copilot_review"] else [] end)
      + (if $terminal != null then ["stop_" + $terminal] else [] end)
      | if length == 0 then ["wait"] else . end)
   end) as $actions
| ($prior.fingerprint // null) as $pf
| $s + {
    terminal: $terminal,
    blockers: $blockers,
    actions: $actions,
    # Plain `!=` rather than `$pf[.] // null`: jq's alternative operator treats
    # `false` as absent, which would report every boolean field as changed.
    changed: (if $pf == null then ["initial"]
              else [ $s.fingerprint | keys[] | select($s.fingerprint[.] != $pf[.]) ]
              end),
    new_thread_ids: [ $s.reviews.threads[].thread_id
                      | select((($prior.known_thread_ids // []) | index(.)) == null) ]
  }
