#!/usr/bin/env bash
set -euo pipefail

# Emit one JSON snapshot of a pull request's CI, review threads, mergeability,
# and Copilot review round, plus the actions a watcher should take next.
#
# --wait long-polls instead of returning immediately. A monitoring loop then
# costs one tool call per state *change* rather than one per poll interval,
# which is what makes hour-long babysitting affordable in a single session.
#
# State (fingerprint, seen threads, rerun/Copilot round counters) is persisted
# so budgets survive across invocations and "what changed" stays answerable.
#
# Sourcing this file defines its functions without running anything, which is
# how test-pr-watch.sh exercises them.

# Physical path on purpose: other agents reach this script through a
# ~/.agents/skills symlink, and ../../../scripts/lib only exists from the
# real location.
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
LIB_DIR="$(cd -- "${SCRIPT_DIR}/../../../scripts/lib" && pwd)"
readonly LIB_DIR
readonly SNAPSHOT_JQ="${SCRIPT_DIR}/snapshot.jq"
readonly GH_MIN_VERSION_COPILOT="2.88.0"

pr_arg="auto"
action="once"
interval=30
timeout_secs=420
retry_budget=3
copilot_cap=5
copilot_stall=900
log_lines=80
state_file=""
owner=""
repo=""
pr_number=""
prior="{}"

usage() {
  cat <<'EOF'
Usage: pr-watch.sh [--pr <number|url|auto>] [action] [options]

Actions (default: --once):
  --once                    Emit one snapshot and exit.
  --wait                    Block until the snapshot changes, then emit it.
  --retry-failed            Rerun failed jobs on the head SHA (budget-limited).
  --request-copilot-review  Request (or re-request) a Copilot code review.
  --failed-logs             Print trimmed logs for failed jobs on the head SHA.
  --reset-state             Delete the saved state file and exit.

Options:
  --pr <number|url|auto>    Target PR ("auto" infers from the current branch).
  --interval <seconds>      Poll interval for --wait (default: 30).
  --timeout <seconds>       Stop waiting after this long (default: 420).
  --retry-budget <n>        Max flaky rerun cycles per head SHA (default: 3).
  --copilot-cap <n>         Max Copilot review rounds per PR (default: 5).
  --copilot-stall <secs>    Flag a Copilot request that produced no review after
                            this long as a blocker (default: 900).
  --log-lines <n>           Log tail length for --failed-logs (default: 80).
  --state-file <path>       Override the state file location.
  -h, --help                Show this help.
EOF
}

version_ge() {
  awk -v have="$1" -v want="$2" 'BEGIN {
    nh = split(have, h, "."); nw = split(want, w, ".");
    n = (nh > nw ? nh : nw);
    for (i = 1; i <= n; i++) {
      hi = (i <= nh ? h[i] + 0 : 0); wi = (i <= nw ? w[i] + 0 : 0);
      if (hi > wi) { print "1"; exit }
      if (hi < wi) { print "0"; exit }
    }
    print "1"
  }'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pr) pr_arg="${2:?--pr requires a value}"; shift 2 ;;
      --once | --wait | --retry-failed | --request-copilot-review | --failed-logs | --reset-state)
        action="${1#--}"; shift ;;
      --interval) interval="${2:?--interval requires a value}"; shift 2 ;;
      --timeout) timeout_secs="${2:?--timeout requires a value}"; shift 2 ;;
      --retry-budget) retry_budget="${2:?--retry-budget requires a value}"; shift 2 ;;
      --copilot-cap) copilot_cap="${2:?--copilot-cap requires a value}"; shift 2 ;;
      --copilot-stall) copilot_stall="${2:?--copilot-stall requires a value}"; shift 2 ;;
      --log-lines) log_lines="${2:?--log-lines requires a value}"; shift 2 ;;
      --state-file) state_file="${2:?--state-file requires a value}"; shift 2 ;;
      -h | --help) usage; exit 0 ;;
      *) printf 'Error: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
  done
}

# Resolve owner/repo/number. A PR URL wins over the local checkout so a PR in
# another repository can be watched without switching directories.
resolve_target() {
  local url_path url_rest owner_repo
  if [[ "${pr_arg}" == http*://* ]]; then
    url_path="${pr_arg#*://}"
    url_path="${url_path#*/}"
    owner="${url_path%%/*}"
    url_rest="${url_path#*/}"
    repo="${url_rest%%/*}"
    pr_number="${pr_arg##*/pull/}"
    pr_number="${pr_number%%[!0-9]*}"
  else
    if ! owner_repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>&1)"; then
      printf 'Error: not inside a GitHub repository (%s).\n' "${owner_repo}" >&2
      exit 1
    fi
    owner="${owner_repo%%/*}"
    repo="${owner_repo##*/}"
    if [[ "${pr_arg}" == "auto" ]]; then
      if ! pr_number="$(gh pr view --json number --jq '.number' 2>&1)"; then
        printf 'Error: no pull request found for the current branch (%s).\n' "${pr_number}" >&2
        exit 1
      fi
    else
      pr_number="${pr_arg#\#}"
    fi
  fi

  if [[ ! "${pr_number}" =~ ^[0-9]+$ ]]; then
    printf 'Error: could not resolve a PR number from: %s\n' "${pr_arg}" >&2
    exit 1
  fi

  if [[ -z "${state_file}" ]]; then
    state_file="${TMPDIR:-/tmp}/claude-babysit-pr/${owner}-${repo}-${pr_number}.json"
  fi
}

load_state() {
  if [[ -f "${state_file}" ]] && jq empty "${state_file}" > /dev/null 2>&1; then
    prior="$(< "${state_file}")"
  else
    prior="{}"
  fi
}

# The reviewRequests / reviewThreads selections are shared fragments in
# scripts/lib, so the reviewer type fragments and the PENDING-filter fields
# cannot drift from read-unresolved-pr-comments.sh.
graphql_query() {
  cat <<'EOF'
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      number
      url
      title
      state
      isDraft
      mergeable
      mergeStateStatus
      reviewDecision
      baseRefName
      headRefName
      headRefOid
      author { login }
EOF
  cat "${LIB_DIR}/review-requests.graphql"
  cat <<'EOF'
      reviews(last: 30) {
        nodes {
          state
          submittedAt
          author { login }
          commit { oid }
        }
      }
EOF
  cat "${LIB_DIR}/review-threads.graphql"
  cat <<'EOF'
      commits(last: 1) {
        nodes {
          commit {
            oid
            statusCheckRollup {
              state
              contexts(first: 100) {
                nodes {
                  __typename
                  ... on CheckRun {
                    name
                    status
                    conclusion
                    detailsUrl
                    checkSuite { workflowRun { databaseId workflow { name } } }
                  }
                  ... on StatusContext {
                    context
                    state
                    targetUrl
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
EOF
}

local_json() {
  local branch head dirty unpushed
  branch="$(git rev-parse --abbrev-ref HEAD 2> /dev/null || printf 'unknown')"
  head="$(git rev-parse HEAD 2> /dev/null || printf '')"
  dirty=false
  if [[ -n "$(git status --porcelain 2> /dev/null)" ]]; then
    dirty=true
  fi
  unpushed="$(git rev-list --count '@{upstream}..HEAD' 2> /dev/null || printf '0')"
  jq -n \
    --arg branch "${branch}" \
    --arg head "${head}" \
    --argjson dirty "${dirty}" \
    --argjson unpushed "${unpushed}" \
    '{current_branch: $branch, head_sha: $head, dirty: $dirty, unpushed_commits: $unpushed}'
}

build_snapshot() {
  local raw mergeable state attempt=0 now local_info
  while :; do
    if ! raw="$(gh api graphql \
      -f owner="${owner}" \
      -f repo="${repo}" \
      -F number="${pr_number}" \
      -f query="$(graphql_query)")"; then
      printf 'Error: GraphQL query for %s/%s#%s failed (gh error above).\n' \
        "${owner}" "${repo}" "${pr_number}" >&2
      exit 1
    fi
    # A partial response (renamed repo, lost token scope, secondary rate
    # limit) has no pullRequest; surface the API's own message instead of
    # letting the snapshot derivation run on nulls.
    if [[ "$(jq -r '.data.repository.pullRequest != null' <<< "${raw}")" != "true" ]]; then
      printf 'Error: no pull request data returned for %s/%s#%s.\n' \
        "${owner}" "${repo}" "${pr_number}" >&2
      jq -r '(.errors // [])[] | "  " + .message' <<< "${raw}" 2> /dev/null \
        || printf '%s\n' "${raw}" >&2
      exit 1
    fi
    mergeable="$(jq -r '.data.repository.pullRequest.mergeable // "UNKNOWN"' <<< "${raw}")"
    state="$(jq -r '.data.repository.pullRequest.state // "UNKNOWN"' <<< "${raw}")"
    # GitHub computes mergeability lazily; a first read often returns UNKNOWN.
    if [[ "${mergeable}" != "UNKNOWN" || "${state}" != "OPEN" || "${attempt}" -ge 3 ]]; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local_info="$(local_json)"

  jq -n \
    -L "${LIB_DIR}" \
    --argjson raw "${raw}" \
    --argjson prior "${prior}" \
    --argjson local "${local_info}" \
    --arg now "${now}" \
    --argjson now_epoch "$(date +%s)" \
    --argjson budget "${retry_budget}" \
    --argjson cap "${copilot_cap}" \
    --argjson stall "${copilot_stall}" \
    --from-file "${SNAPSHOT_JQ}"
}

# `fingerprint` is bookkeeping for change detection; `changed` already names the
# keys that moved, so printing it would only spend context.
emit() {
  jq "del(.fingerprint) ${2:-}" <<< "$1"
}

# Persist fingerprint, seen threads, and budget counters. Counter deltas are
# passed in so an action (rerun / Copilot request) records itself in the same
# step it acts, and an interrupted session cannot silently reset a budget.
save_state() {
  local snapshot="$1" retry_delta="${2:-0}" copilot_delta="${3:-0}" tmp
  tmp="${state_file}.$$"
  jq -n \
    --argjson prior "${prior}" \
    --argjson snap "${snapshot}" \
    --argjson retry_delta "${retry_delta}" \
    --argjson copilot_delta "${copilot_delta}" \
    --argjson now_epoch "$(date +%s)" \
    '$snap.pr.head_sha as $head
     | {
         pr: $snap.pr.number,
         fingerprint: $snap.fingerprint,
         known_thread_ids: ((($prior.known_thread_ids // [])
                             + [$snap.reviews.threads[].thread_id]) | unique),
         retries: (($prior.retries // {})
                   + {($head): (($prior.retries[$head] // 0) + $retry_delta)}),
         copilot_rounds: (($prior.copilot_rounds // 0) + $copilot_delta),
         copilot_requested_at: (if $copilot_delta > 0 then $now_epoch
                                else ($prior.copilot_requested_at // null) end),
         updated_at: $snap.polled_at
       }' > "${tmp}"
  mv "${tmp}" "${state_file}"
}

action_once() {
  local snapshot
  snapshot="$(build_snapshot)"
  save_state "${snapshot}"
  emit "${snapshot}"
}

action_wait() {
  local deadline snapshot
  deadline=$(($(date +%s) + timeout_secs))
  while :; do
    snapshot="$(build_snapshot)"
    if [[ "$(jq -r '.changed | length' <<< "${snapshot}")" -gt 0 ]]; then
      save_state "${snapshot}"
      emit "${snapshot}"
      return 0
    fi
    if [[ "$(date +%s)" -ge "${deadline}" ]]; then
      save_state "${snapshot}"
      emit "${snapshot}" '| .timed_out = true'
      return 0
    fi
    sleep "${interval}"
  done
}

action_retry_failed() {
  local snapshot head_sha used run_ids run_id rerun_ids=""
  snapshot="$(build_snapshot)"
  head_sha="$(jq -r '.pr.head_sha' <<< "${snapshot}")"
  used="$(jq -r '.retries.used' <<< "${snapshot}")"
  if [[ "${used}" -ge "${retry_budget}" ]]; then
    printf 'Error: flaky retry budget exhausted for %s (%s/%s). Report the blocker instead.\n' \
      "${head_sha:0:7}" "${used}" "${retry_budget}" >&2
    exit 3
  fi
  run_ids="$(jq -r '.ci.failed_run_ids[]' <<< "${snapshot}")"
  if [[ -z "${run_ids}" ]]; then
    printf 'No failed workflow runs on %s to rerun.\n' "${head_sha:0:7}"
    return 0
  fi
  while IFS= read -r run_id; do
    [[ -n "${run_id}" ]] || continue
    if gh run rerun "${run_id}" --repo "${owner}/${repo}" --failed > /dev/null 2>&1; then
      rerun_ids="${rerun_ids}${run_id} "
    else
      printf 'Warning: could not rerun workflow run %s.\n' "${run_id}" >&2
    fi
  done <<< "${run_ids}"
  save_state "${snapshot}" 1 0
  jq -n \
    --arg head "${head_sha}" \
    --arg rerun "${rerun_ids% }" \
    --argjson used "$((used + 1))" \
    --argjson budget "${retry_budget}" \
    '{action: "retry_failed", head_sha: $head,
      rerun_run_ids: ($rerun | split(" ") | map(select(. != ""))),
      retries_used: $used, retry_budget: $budget}'
}

action_request_copilot_review() {
  local gh_version snapshot head_sha rounds result
  gh_version="$(gh --version | head -n 1 | awk '{print $3}')"
  if [[ "$(version_ge "${gh_version}" "${GH_MIN_VERSION_COPILOT}")" != "1" ]]; then
    printf 'Error: gh %s or newer is required to request a Copilot review (found %s).\n' \
      "${GH_MIN_VERSION_COPILOT}" "${gh_version}" >&2
    exit 1
  fi
  snapshot="$(build_snapshot)"
  head_sha="$(jq -r '.pr.head_sha' <<< "${snapshot}")"
  rounds="$(jq -r '.copilot.rounds_used' <<< "${snapshot}")"
  if [[ "${rounds}" -ge "${copilot_cap}" ]]; then
    printf 'Error: Copilot review round cap reached (%s/%s). Report the loop to the user instead.\n' \
      "${rounds}" "${copilot_cap}" >&2
    exit 3
  fi
  if ! result="$(gh pr edit "${pr_number}" --repo "${owner}/${repo}" --add-reviewer "@copilot" 2>&1)"; then
    printf 'Error: could not request a Copilot review.\n%s\n' "${result}" >&2
    exit 4
  fi
  save_state "${snapshot}" 0 1
  jq -n \
    --arg head "${head_sha}" \
    --argjson rounds "$((rounds + 1))" \
    --argjson cap "${copilot_cap}" \
    '{action: "request_copilot_review", head_sha: $head, rounds_used: $rounds, rounds_cap: $cap}'
}

# Actions logs stamp every line with an ISO timestamp and end with ~20 lines of
# post-job cleanup. Tailing them raw spends most of the window on boilerplate, so
# drop the cleanup section and the timestamps before taking the tail.
trim_job_log() {
  sed -e 's/^[0-9][0-9-]*T[0-9:.]*Z //' \
      -e '/^\(##\[group\]\)\{0,1\}Post job cleanup/,$d' \
    | tail -n "${log_lines}"
}

action_failed_logs() {
  local snapshot run_ids run_id jobs failed_jobs="" job_id job_name
  snapshot="$(build_snapshot)"
  run_ids="$(jq -r '.ci.failed_run_ids[]' <<< "${snapshot}")"
  if [[ -z "${run_ids}" ]]; then
    printf 'No failed workflow runs on the head SHA.\n'
    return 0
  fi
  while IFS= read -r run_id; do
    [[ -n "${run_id}" ]] || continue
    jobs="$(gh api "repos/${owner}/${repo}/actions/runs/${run_id}/jobs" --paginate \
      --jq '.jobs[] | select(.conclusion == "failure") | "\(.id)\t\(.name)"' 2>&1 || printf '')"
    failed_jobs="${failed_jobs}${jobs}"$'\n'
  done <<< "${run_ids}"
  while IFS=$'\t' read -r job_id job_name; do
    [[ "${job_id}" =~ ^[0-9]+$ ]] || continue
    printf '\n===== failed job: %s (id %s, last %s lines) =====\n' \
      "${job_name}" "${job_id}" "${log_lines}"
    if ! gh api "repos/${owner}/${repo}/actions/jobs/${job_id}/logs" 2> /dev/null \
      | trim_job_log; then
      printf '(logs unavailable — the job may still be uploading them)\n'
    fi
  done <<< "${failed_jobs}"
}

main() {
  local cmd
  parse_args "$@"

  for cmd in gh jq git; do
    if ! command -v "${cmd}" > /dev/null 2>&1; then
      printf 'Error: %s is required but not installed.\n' "${cmd}" >&2
      exit 1
    fi
  done

  resolve_target

  if [[ "${action}" == "reset-state" ]]; then
    rm -f "${state_file}"
    printf 'State reset: %s\n' "${state_file}"
    return 0
  fi

  mkdir -p "$(dirname "${state_file}")"
  load_state

  case "${action}" in
    once) action_once ;;
    wait) action_wait ;;
    retry-failed) action_retry_failed ;;
    request-copilot-review) action_request_copilot_review ;;
    failed-logs) action_failed_logs ;;
    *) printf 'Error: unsupported action: %s\n' "${action}" >&2; exit 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
