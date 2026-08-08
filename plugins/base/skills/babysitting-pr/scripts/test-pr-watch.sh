#!/usr/bin/env bash
set -euo pipefail

# Offline tests for pr-watch.sh: the snapshot.jq derivation layer (terminal
# state, blockers, actions), state persistence, and the gh version gate.
#
# The snapshot rules decide when babysitting stops, so a regression here either
# strands a watcher forever or hands a PR back as "mergeable" while it still has
# failing checks. State persistence guards the rerun and Copilot round budgets:
# if it silently resets, a broken CI loop runs unbounded.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR

# Defines the functions without running main(), thanks to the source guard.
# shellcheck source=./pr-watch.sh disable=SC1091  # CI runs shellcheck without -x
. "${TEST_DIR}/pr-watch.sh"

pass_count=0
fail_count=0

base_pr() {
  cat <<'EOF'
{
  "number": 1,
  "url": "https://github.com/o/r/pull/1",
  "title": "[main] feat: add thing",
  "state": "OPEN",
  "isDraft": false,
  "mergeable": "MERGEABLE",
  "mergeStateStatus": "CLEAN",
  "reviewDecision": null,
  "baseRefName": "main",
  "headRefName": "feature/x",
  "headRefOid": "sha-new",
  "author": { "login": "kkhys" },
  "reviewRequests": { "nodes": [] },
  "reviews": { "nodes": [] },
  "reviewThreads": { "nodes": [] },
  "commits": {
    "nodes": [
      {
        "commit": {
          "oid": "sha-new",
          "statusCheckRollup": {
            "state": "SUCCESS",
            "contexts": {
              "nodes": [
                {
                  "__typename": "CheckRun",
                  "name": "Validate manifests",
                  "status": "COMPLETED",
                  "conclusion": "SUCCESS",
                  "detailsUrl": "https://example.test/1",
                  "checkSuite": {
                    "workflowRun": { "databaseId": 100, "workflow": { "name": "validate" } }
                  }
                }
              ]
            }
          }
        }
      }
    ]
  }
}
EOF
}

# Build a snapshot from a pullRequest fixture, optionally with prior state.
snapshot() {
  local pr_json="$1"
  local prior_json="${2:-}"
  local raw
  [[ -n "${prior_json}" ]] || prior_json='{}'
  raw="$(jq -n --argjson pr "${pr_json}" '{data: {repository: {pullRequest: $pr}}}')"
  jq -n \
    -L "${LIB_DIR}" \
    --argjson raw "${raw}" \
    --argjson prior "${prior_json}" \
    --argjson local '{"current_branch":"feature/x","head_sha":"sha-new","dirty":false,"unpushed_commits":0}' \
    --arg now "2026-08-04T00:00:00Z" \
    --argjson now_epoch 1000000 \
    --argjson budget 3 \
    --argjson cap 5 \
    --argjson stall 900 \
    --from-file "${SNAPSHOT_JQ}"
}

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "${expected}" == "${actual}" ]]; then
    printf 'ok   %s\n' "${label}"
    pass_count=$((pass_count + 1))
  else
    printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' \
      "${label}" "${expected}" "${actual}" >&2
    fail_count=$((fail_count + 1))
  fi
}

# Assert on a jq expression evaluated against the snapshot.
expect() {
  local label="$1" pr_json="$2" filter="$3" expected="$4" prior_json="${5:-}"
  local actual
  actual="$(snapshot "${pr_json}" "${prior_json}" | jq -c "${filter}")"
  check "${label}" "${expected}" "${actual}"
}

failing_check() {
  cat <<'EOF'
{
  "__typename": "CheckRun",
  "name": "ShellCheck",
  "status": "COMPLETED",
  "conclusion": "FAILURE",
  "detailsUrl": "https://example.test/2",
  "checkSuite": { "workflowRun": { "databaseId": 100, "workflow": { "name": "validate" } } }
}
EOF
}

pending_check() {
  cat <<'EOF'
{
  "__typename": "CheckRun",
  "name": "Slow test",
  "status": "IN_PROGRESS",
  "conclusion": null,
  "detailsUrl": "https://example.test/3",
  "checkSuite": { "workflowRun": { "databaseId": 101, "workflow": { "name": "validate" } } }
}
EOF
}

copilot_thread() {
  local review_state="${1:-SUBMITTED}"
  jq -n --arg state "${review_state}" '{
    id: "THREAD_1",
    isResolved: false,
    isOutdated: false,
    path: "plugins/base/scripts/x.sh",
    line: 12,
    startLine: null,
    comments: {
      nodes: [
        {
          author: { login: "copilot-pull-request-reviewer[bot]" },
          authorAssociation: "NONE",
          body: "Quote this variable.",
          url: "https://example.test/c1",
          createdAt: "2026-08-04T00:00:00Z",
          pullRequestReview: { state: $state }
        }
      ]
    }
  }'
}

BASE="$(base_pr)"
readonly BASE

# --- terminal state ----------------------------------------------------------

expect 'green + clean + MERGEABLE reaches the mergeable terminal' \
  "${BASE}" '[.terminal, .actions]' '["mergeable",["stop_mergeable"]]'

expect 'BLOCKED on approval alone still counts as mergeable' \
  "$(jq '.mergeStateStatus = "BLOCKED" | .reviewDecision = "REVIEW_REQUIRED"' <<< "${BASE}")" \
  '.terminal' '"mergeable"'

expect 'a PR with no checks configured is treated as green' \
  "$(jq '.commits.nodes[0].commit.statusCheckRollup = null' <<< "${BASE}")" \
  '[.ci.total, .ci.is_green, .terminal]' '[0,true,"mergeable"]'

expect 'draft PR with nothing outstanding reaches its own terminal' \
  "$(jq '.isDraft = true | .mergeStateStatus = "DRAFT"' <<< "${BASE}")" \
  '[.terminal, .actions]' '["draft_review_clean",["stop_draft_review_clean"]]'

expect 'UNKNOWN mergeability keeps the watcher polling' \
  "$(jq '.mergeable = "UNKNOWN" | .mergeStateStatus = "UNKNOWN"' <<< "${BASE}")" \
  '[.terminal, .actions]' '[null,["wait"]]'

expect 'merged PR stops immediately' \
  "$(jq '.state = "MERGED"' <<< "${BASE}")" \
  '[.terminal, .actions]' '["merged",["stop_pr_merged"]]'

expect 'closed PR stops immediately' \
  "$(jq '.state = "CLOSED"' <<< "${BASE}")" \
  '[.terminal, .actions]' '["closed",["stop_pr_closed"]]'

# --- CI ----------------------------------------------------------------------

expect 'a terminal failure suggests diagnosis and a budgeted rerun' \
  "$(jq --argjson c "$(failing_check)" \
    '.commits.nodes[0].commit.statusCheckRollup.contexts.nodes += [$c]' <<< "${BASE}")" \
  '[.ci.failed, .ci.failed_run_ids, .terminal, .actions]' \
  '[1,[100],null,["diagnose_ci_failure","retry_failed_checks"]]'

expect 'a failure with checks still pending is diagnosed but not rerun' \
  "$(jq --argjson f "$(failing_check)" --argjson p "$(pending_check)" \
    '.commits.nodes[0].commit.statusCheckRollup.contexts.nodes += [$f, $p]' <<< "${BASE}")" \
  '.actions' '["diagnose_ci_failure"]'

expect 'an exhausted rerun budget becomes a blocker instead of another rerun' \
  "$(jq --argjson c "$(failing_check)" \
    '.commits.nodes[0].commit.statusCheckRollup.contexts.nodes += [$c]' <<< "${BASE}")" \
  '[.blockers, .actions]' '[["retry_budget_exhausted"],["diagnose_ci_failure"]]' \
  '{"retries":{"sha-new":3}}'

expect 'SKIPPED and NEUTRAL conclusions do not count as failures' \
  "$(jq '.commits.nodes[0].commit.statusCheckRollup.contexts.nodes[0].conclusion = "SKIPPED"' <<< "${BASE}")" \
  '[.ci.skipped, .ci.failed, .ci.is_green]' '[1,0,true]'

expect 'a failing legacy status context is bucketed as a failure' \
  "$(jq '.commits.nodes[0].commit.statusCheckRollup.contexts.nodes += [{"__typename":"StatusContext","context":"ci/legacy","state":"FAILURE","targetUrl":"https://example.test/4"}]' <<< "${BASE}")" \
  '[.ci.failed, .ci.failed_run_ids]' '[1,[]]'

# --- review threads ----------------------------------------------------------

expect 'an unresolved thread blocks the terminal and asks to be processed' \
  "$(jq --argjson t "$(copilot_thread)" '.reviewThreads.nodes += [$t]' <<< "${BASE}")" \
  '[.reviews.unresolved_thread_count, .terminal, .actions]' \
  '[1,null,["process_review_comment"]]'

expect 'comments belonging to a PENDING review are not surfaced' \
  "$(jq --argjson t "$(copilot_thread PENDING)" '.reviewThreads.nodes += [$t]' <<< "${BASE}")" \
  '[.reviews.unresolved_thread_count, .terminal]' '[0,"mergeable"]'

expect 'already-seen threads are excluded from new_thread_ids' \
  "$(jq --argjson t "$(copilot_thread)" '.reviewThreads.nodes += [$t]' <<< "${BASE}")" \
  '.new_thread_ids' '[]' '{"known_thread_ids":["THREAD_1"]}'

expect 'a resolved thread is ignored' \
  "$(jq --argjson t "$(copilot_thread)" '.reviewThreads.nodes += [($t | .isResolved = true)]' <<< "${BASE}")" \
  '[.reviews.unresolved_thread_count, .terminal]' '[0,"mergeable"]'

# Regression: a partial GraphQL response (null pullRequest) used to crash the
# derivation with "Cannot iterate over null" and kill the watch loop.
expect 'a null pullRequest yields an empty snapshot instead of a jq crash' \
  'null' '[.pr.number, .reviews.unresolved_thread_count, .actions]' '[null,0,["wait"]]'

# --- Copilot review loop -----------------------------------------------------

expect 'a Copilot review on an older SHA triggers a re-request' \
  "$(jq '.reviews.nodes += [{"state":"COMMENTED","submittedAt":"2026-08-04T00:00:00Z","author":{"login":"copilot-pull-request-reviewer[bot]"},"commit":{"oid":"sha-old"}}]' <<< "${BASE}")" \
  '[.copilot.participant, .copilot.reviewed_head_sha, .terminal, .actions]' \
  '[true,false,null,["request_copilot_review"]]'

expect 'an in-flight Copilot request waits instead of re-requesting' \
  "$(jq '.reviewRequests.nodes += [{"requestedReviewer":{"__typename":"Bot","login":"copilot-pull-request-reviewer"}}]' <<< "${BASE}")" \
  '[.copilot.review_pending, .terminal, .actions]' '[true,null,["wait"]]'

expect 'a Copilot review on the head SHA with no comments closes the loop' \
  "$(jq '.reviews.nodes += [{"state":"COMMENTED","submittedAt":"2026-08-04T00:00:00Z","author":{"login":"copilot-pull-request-reviewer[bot]"},"commit":{"oid":"sha-new"}}]' <<< "${BASE}")" \
  '[.copilot.reviewed_head_sha, .terminal]' '[true,"mergeable"]'

expect 'the Copilot round cap becomes a blocker' \
  "$(jq '.reviews.nodes += [{"state":"COMMENTED","submittedAt":"2026-08-04T00:00:00Z","author":{"login":"copilot-pull-request-reviewer[bot]"},"commit":{"oid":"sha-old"}}]' <<< "${BASE}")" \
  '[.blockers, .actions]' '[["copilot_round_cap"],["wait"]]' \
  '{"copilot_rounds":5}'

# A request that never yields a review changes nothing, so the watcher has
# nothing to detect and would poll until the user gave up.
expect 'a Copilot request that produced no review becomes a blocker' \
  "$(jq '.reviewRequests.nodes += [{"requestedReviewer":{"__typename":"Bot","login":"copilot-pull-request-reviewer"}}]' <<< "${BASE}")" \
  '[.copilot.request_age_seconds, .blockers]' '[1000,["copilot_review_stalled"]]' \
  '{"copilot_requested_at":999000}'

expect 'a request still inside the stall window is not a blocker' \
  "$(jq '.reviewRequests.nodes += [{"requestedReviewer":{"__typename":"Bot","login":"copilot-pull-request-reviewer"}}]' <<< "${BASE}")" \
  '[.copilot.request_age_seconds, .blockers, .actions]' '[300,[],["wait"]]' \
  '{"copilot_requested_at":999700}'

expect 'a state file predating the timestamp field never false-positives' \
  "$(jq '.reviewRequests.nodes += [{"requestedReviewer":{"__typename":"Bot","login":"copilot-pull-request-reviewer"}}]' <<< "${BASE}")" \
  '[.copilot.request_age_seconds, .blockers]' '[null,[]]' \
  '{"copilot_rounds":1}'

expect 'age is not reported once the review has landed' \
  "${BASE}" '.copilot.request_age_seconds' 'null' '{"copilot_requested_at":999000}'

expect 'Copilot threads are counted separately from other reviewers' \
  "$(jq --argjson t "$(copilot_thread)" '.reviewThreads.nodes += [$t] | .reviews.nodes += [{"state":"COMMENTED","submittedAt":"2026-08-04T00:00:00Z","author":{"login":"copilot-pull-request-reviewer[bot]"},"commit":{"oid":"sha-new"}}]' <<< "${BASE}")" \
  '[.copilot.unresolved_thread_count, .copilot.unresolved_thread_ids]' '[1,["THREAD_1"]]'

# --- mergeability ------------------------------------------------------------

expect 'a conflicting PR is a blocker, not something to auto-resolve' \
  "$(jq '.mergeable = "CONFLICTING" | .mergeStateStatus = "DIRTY"' <<< "${BASE}")" \
  '[.blockers, .actions, .terminal]' \
  '[["merge_conflict"],["resolve_merge_conflict"],null]'

expect 'a behind-base PR asks for a branch update' \
  "$(jq '.mergeStateStatus = "BEHIND"' <<< "${BASE}")" \
  '[.actions, .terminal]' '[["update_branch"],null]'

# --- change detection --------------------------------------------------------

expect 'a fresh state file reports the initial snapshot' \
  "${BASE}" '.changed' '["initial"]'

FINGERPRINT="$(snapshot "${BASE}" | jq -c '{fingerprint}')"
readonly FINGERPRINT

# Regression: jq's `//` treats `false` as absent, which reported every boolean
# fingerprint field as changed on every poll and defeated the long-poll.
expect 'an unchanged snapshot reports no changes, including false booleans' \
  "${BASE}" '.changed' '[]' "${FINGERPRINT}"

expect 'a new head SHA is reported as changed' \
  "$(jq '.headRefOid = "sha-newer" | .commits.nodes[0].commit.oid = "sha-newer"' <<< "${BASE}")" \
  '.changed' '["head_sha"]' "${FINGERPRINT}"

expect 'a new review thread is reported as changed' \
  "$(jq --argjson t "$(copilot_thread)" '.reviewThreads.nodes += [$t]' <<< "${BASE}")" \
  '[.changed, .new_thread_ids]' '[["threads"],["THREAD_1"]]' "${FINGERPRINT}"

# --- payload size ------------------------------------------------------------

expect 'only pending check names are carried, not every check' \
  "$(jq --argjson p "$(pending_check)" \
    '.commits.nodes[0].commit.statusCheckRollup.contexts.nodes += [$p]' <<< "${BASE}")" \
  '[.ci.pending_checks, (.ci | has("checks"))]' '[["Slow test"],false]'

expect 'superseded reviews from the same author are dropped' \
  "$(jq '.reviews.nodes += [
      {"state":"COMMENTED","submittedAt":"2026-08-01T00:00:00Z","author":{"login":"alice"},"commit":{"oid":"sha-old"}},
      {"state":"APPROVED","submittedAt":"2026-08-02T00:00:00Z","author":{"login":"alice"},"commit":{"oid":"sha-new"}}
    ]' <<< "${BASE}")" \
  '[(.reviews.submitted | length), .reviews.submitted[0].state]' '[1,"APPROVED"]'

# --- Copilot identity --------------------------------------------------------

expect 'the Copilot coding agent is not mistaken for the review bot' \
  "$(jq '.reviews.nodes += [{"state":"COMMENTED","submittedAt":"2026-08-04T00:00:00Z","author":{"login":"copilot-swe-agent[bot]"},"commit":{"oid":"sha-old"}}]' <<< "${BASE}")" \
  '[.copilot.participant, .terminal]' '[false,"mergeable"]'

expect 'the bare "Copilot" login counts as the review bot' \
  "$(jq '.reviews.nodes += [{"state":"COMMENTED","submittedAt":"2026-08-04T00:00:00Z","author":{"login":"Copilot"},"commit":{"oid":"sha-old"}}]' <<< "${BASE}")" \
  '[.copilot.participant, .actions]' '[true,["request_copilot_review"]]'

# --- failed job log trimming -------------------------------------------------

# Shape taken from a real ShellCheck job failure: the useful lines sit above a
# long post-job cleanup section, and every line carries an ISO timestamp.
job_log_fixture() {
  cat <<'EOF'
2026-08-04T03:09:26.4891885Z      ^-----^ SC2086 (info): Double quote to prevent globbing.
2026-08-04T03:09:26.4933700Z ##[error]Process completed with exit code 1.
2026-08-04T03:09:26.5092425Z Node 20 is being deprecated.
2026-08-04T03:09:26.5094264Z Post job cleanup.
2026-08-04T03:09:26.6075121Z [command]/usr/bin/git version
2026-08-04T03:09:26.7409014Z Cleaning up orphan processes
EOF
}

# shellcheck disable=SC2034  # read by trim_job_log from the sourced script
log_lines=50
check 'timestamps and the post-job cleanup section are dropped' \
  '     ^-----^ SC2086 (info): Double quote to prevent globbing.
##[error]Process completed with exit code 1.
Node 20 is being deprecated.' \
  "$(job_log_fixture | trim_job_log)"

check 'the grouped form of the cleanup marker is also cut' \
  'boom' \
  "$(printf '2026-08-04T03:09:26.1Z boom\n2026-08-04T03:09:26.2Z ##[group]Post job cleanup\n2026-08-04T03:09:26.3Z noise\n' | trim_job_log)"

# shellcheck disable=SC2034  # read by trim_job_log from the sourced script
log_lines=2
check 'the tail limit still applies after trimming' \
  '##[error]Process completed with exit code 1.
Node 20 is being deprecated.' \
  "$(job_log_fixture | trim_job_log)"

# --- version gate ------------------------------------------------------------

check 'gh 2.96.0 satisfies the 2.88.0 Copilot requirement' \
  '1' "$(version_ge 2.96.0 2.88.0)"
check 'gh 2.87.9 does not satisfy it' \
  '0' "$(version_ge 2.87.9 2.88.0)"
check 'a shorter version string is padded, not rejected' \
  '1' "$(version_ge 2.88 2.88.0)"
check 'versions compare numerically, not lexically' \
  '1' "$(version_ge 10.0.0 9.9.9)"

# --- state persistence -------------------------------------------------------

STATE_TMP="$(mktemp)"
readonly STATE_TMP
trap 'rm -f "${STATE_TMP}"' EXIT
# shellcheck disable=SC2034  # read by save_state from the sourced script
state_file="${STATE_TMP}"

# save_state reads $prior and $state_file as globals, mirroring the real run.
save_and_read() {
  local snapshot="$1" retry_delta="${2:-0}" copilot_delta="${3:-0}"
  save_state "${snapshot}" "${retry_delta}" "${copilot_delta}"
  cat "${STATE_TMP}"
}

SNAP_A="$(snapshot "$(jq --argjson t "$(copilot_thread)" '.reviewThreads.nodes += [$t]' <<< "${BASE}")")"
readonly SNAP_A

prior='{}'
prior="$(save_and_read "${SNAP_A}" 1 0)"
check 'the first rerun is recorded against the head SHA' \
  '{"sha-new":1}' "$(jq -c '.retries' <<< "${prior}")"

prior="$(save_and_read "${SNAP_A}" 1 1)"
check 'budget counters accumulate instead of overwriting' \
  '[{"sha-new":2},1]' "$(jq -c '[.retries, .copilot_rounds]' <<< "${prior}")"

# Regression guard: a plain --once must not look like a budget reset.
prior="$(save_and_read "${SNAP_A}")"
check 'a snapshot with no action preserves the counters' \
  '[{"sha-new":2},1]' "$(jq -c '[.retries, .copilot_rounds]' <<< "${prior}")"

check 'threads seen once stay known' \
  '["THREAD_1"]' "$(jq -c '.known_thread_ids' <<< "${prior}")"

# The stall blocker is only as good as this timestamp surviving plain polls.
check 'requesting a review stamps the request time' \
  'number' "$(jq -r '.copilot_requested_at | type' <<< "${prior}")"

REQUESTED_AT="$(jq -r '.copilot_requested_at' <<< "${prior}")"
readonly REQUESTED_AT
prior="$(save_and_read "${SNAP_A}")"
check 'a snapshot with no action preserves the request time' \
  "${REQUESTED_AT}" "$(jq -r '.copilot_requested_at' <<< "${prior}")"

SNAP_B="$(snapshot "$(jq '.headRefOid = "sha-2" | .commits.nodes[0].commit.oid = "sha-2"' <<< "${BASE}")")"
readonly SNAP_B
prior="$(save_and_read "${SNAP_B}" 1 0)"
check 'a new head SHA starts its own rerun budget' \
  '{"sha-2":1,"sha-new":2}' "$(jq -cS '.retries' <<< "${prior}")"
check 'known threads survive a SHA change' \
  '["THREAD_1"]' "$(jq -c '.known_thread_ids' <<< "${prior}")"

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
