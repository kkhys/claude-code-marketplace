#!/usr/bin/env bash
set -euo pipefail

# Payload validation tests for reply-to-review-threads.sh.
#
# Only the paths that reject a payload run offline — a valid payload would post
# to GitHub. That is the part worth pinning down anyway: a malformed entry found
# mid-loop used to abort after earlier replies had already been posted, leaving
# threads half-answered.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/reply-to-review-threads.sh"
LIB_DIR="$(cd -- "${TEST_DIR}/../../../scripts/lib" && pwd)"
readonly LIB_DIR

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# Assert the script's exit code and that its output mentions `expect_output`.
expect_reject() {
  local label="$1" payload="$2" expect_code="$3" expect_output="$4"
  local file="${WORK_DIR}/payload.json" output code=0
  printf '%s' "${payload}" > "${file}"
  output="$(bash "${SCRIPT}" "${file}" 2>&1)" || code=$?
  if [[ "${code}" -eq "${expect_code}" && "${output}" == *"${expect_output}"* ]]; then
    printf 'ok   %s\n' "${label}"
    pass_count=$((pass_count + 1))
  else
    printf 'FAIL %s\n       expected: exit %s containing %q\n       actual:   exit %s: %s\n' \
      "${label}" "${expect_code}" "${expect_output}" "${code}" "${output}" >&2
    fail_count=$((fail_count + 1))
  fi
}

expect_reject 'a missing body is rejected before anything is posted' \
  '{"replies":[{"thread_id":"T1"}]}' 1 'lack a non-empty thread_id and body'

expect_reject 'a null body is rejected' \
  '{"replies":[{"thread_id":"T1","body":null}]}' 1 'lack a non-empty thread_id and body'

expect_reject 'an empty body is rejected' \
  '{"replies":[{"thread_id":"T1","body":""}]}' 1 'lack a non-empty thread_id and body'

expect_reject 'a missing thread_id is rejected' \
  '{"replies":[{"body":"fixed in abc1234"}]}' 1 'lack a non-empty thread_id and body'

# The whole batch is rejected, not just the bad entry: posting the good half
# would leave the caller unable to tell which threads still need a reply.
expect_reject 'one bad entry rejects the entire batch' \
  '{"replies":[{"thread_id":"T1","body":"ok"},{"thread_id":"T2"}]}' \
  1 '1 of 2 replies'

expect_reject 'a non-array replies field is rejected' \
  '{"replies":"nope"}' 1 "must contain a 'replies' array"

expect_reject 'invalid JSON is rejected' \
  '{"replies":' 1 'Invalid JSON'

expect_reject 'an empty replies array is a no-op, not an error' \
  '{"replies":[]}' 0 'No replies to post.'

# Guards the marker contract the callers rely on: idempotent, first-token.
# Exercises the shared attribution module the scripts themselves load, not a
# copy of the expression, so drift in scripts/lib/attribution.jq fails here.
check_marker() {
  local label="$1" input="$2" expected="$3" actual
  actual="$(jq -rn -L "${LIB_DIR}" --argjson body "${input}" \
    'include "attribution"; $body | attribute')"
  if [[ "${actual}" == "${expected}" ]]; then
    printf 'ok   %s\n' "${label}"
    pass_count=$((pass_count + 1))
  else
    printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' \
      "${label}" "${expected}" "${actual}" >&2
    fail_count=$((fail_count + 1))
  fi
}

check_marker 'the marker is prepended to a plain body' \
  '"abc1234 で修正しました。"' '[from Claude Code] abc1234 で修正しました。'
check_marker 'an already-marked body is left alone' \
  '"[from Claude Code] すでに付いている"' '[from Claude Code] すでに付いている'
check_marker 'a null body becomes the bare marker' \
  'null' '[from Claude Code]'
check_marker 'an empty body becomes the bare marker' \
  '""' '[from Claude Code]'

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
