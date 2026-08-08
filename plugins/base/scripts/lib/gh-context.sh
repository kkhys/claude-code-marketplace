#!/usr/bin/env bash

# Shared GitHub context resolution for the PR skill scripts.
#
# Source this file, then call gh_context to set OWNER, REPO, PR_NUMBER, PR_URL,
# and HEAD_OID for the current branch's open pull request. Centralized so every
# script fails with the same actionable message instead of gh's raw stderr.
#
# Sourced library: sets no shell options — callers own set -euo pipefail.

# shellcheck disable=SC2034  # the variables are this function's output, consumed by the sourcing script
gh_context() {
  local owner_repo pr_json
  # GH_NO_UPDATE_NOTIFIER: stderr is merged into the captured value to surface
  # gh's error on failure; an upgrade notice would corrupt it on success.
  if ! owner_repo="$(GH_NO_UPDATE_NOTIFIER=1 gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>&1)"; then
    echo "Error: not inside a GitHub repository (${owner_repo})" >&2
    return 1
  fi
  OWNER="${owner_repo%%/*}"
  REPO="${owner_repo##*/}"
  if ! pr_json="$(GH_NO_UPDATE_NOTIFIER=1 gh pr view --json number,url,headRefOid 2>&1)"; then
    echo "Error: no pull request found for the current branch (${pr_json})" >&2
    return 1
  fi
  PR_NUMBER="$(jq -r '.number' <<< "${pr_json}")"
  PR_URL="$(jq -r '.url' <<< "${pr_json}")"
  HEAD_OID="$(jq -r '.headRefOid' <<< "${pr_json}")"
}
