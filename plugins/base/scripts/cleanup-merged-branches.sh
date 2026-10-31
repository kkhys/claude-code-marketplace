#!/usr/bin/env bash
set -euo pipefail

# Stop hook: delete local branches whose work has already landed on the base
# branch. Two signals, because PRs land both ways:
#   - ancestry: the tip is reachable from main or origin/main (merge commits).
#     origin/main counts too, so a fetch on a feature branch is enough; local
#     main often lags for days.
#   - gone upstream: the remote branch was deleted after a squash merge, which
#     ancestry can never see. Relies on pruned remote-tracking refs
#     (fetch.prune = true in dotfiles); this script never fetches. A gone
#     upstream alone is not proof, though: commits made after the last push
#     would be lost. So the local tip must also be the head of a merged PR,
#     which GitHub still knows after the branch is gone.
# Runs synchronously and reports through systemMessage, so the user sees what
# was deleted instead of discovering it later.

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

readonly PROTECTED_BRANCHES=(main master develop staging production)

log() {
  echo "[${SCRIPT_NAME}] $*" >&2
}

join_by() {
  local sep="$1" out="" item
  shift
  for item in "$@"; do
    out+="${out:+${sep}}${item}"
  done
  printf '%s' "${out}"
}

# Ref names cannot contain backslashes or control characters, so quotes are the
# only thing to escape.
json_escape() {
  printf '%s' "$1" | sed 's/"/\\"/g'
}

# The shell cwd drifts whenever the model cd's elsewhere mid-session; the
# project dir is where the session was started.
if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "${CLAUDE_PROJECT_DIR}" ]]; then
  cd "${CLAUDE_PROJECT_DIR}"
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  log "Not in a git repository, skipping"
  exit 0
fi

base_branch=""
for candidate in main master; do
  if git show-ref --verify --quiet "refs/heads/${candidate}"; then
    base_branch="${candidate}"
    break
  fi
done
if [[ -z "${base_branch}" ]]; then
  log "No main or master branch, skipping"
  exit 0
fi

base_refs=("${base_branch}")
remote="$(git config --get "branch.${base_branch}.remote" || echo origin)"
if git show-ref --verify --quiet "refs/remotes/${remote}/${base_branch}"; then
  base_refs+=("${remote}/${base_branch}")
fi

current_branch="$(git branch --show-current)"

is_protected() {
  local name="$1" protected
  for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "${name}" == "${protected}" ]]; then
      return 0
    fi
  done
  return 1
}

# Head SHAs of merged PRs opened from the branch, one per line. Fails without
# gh, offline, or outside GitHub, in which case the caller keeps the branch.
merged_pr_heads() {
  command -v gh > /dev/null 2>&1 || return 1
  gh pr list --head "$1" --state merged --json headRefOid --jq '.[].headRefOid' 2> /dev/null
}

# Prints "merged" or "gone" when the branch is safe to delete, "stale" when
# its upstream is gone but the tip is not the head of any merged PR, and
# fails when there is nothing to do.
landed_reason() {
  local branch="$1" track="$2" ref tip heads
  for ref in "${base_refs[@]}"; do
    if git merge-base --is-ancestor "${branch}" "${ref}"; then
      echo "merged"
      return 0
    fi
  done
  if [[ "${track}" != "[gone]" ]]; then
    return 1
  fi
  heads="$(merged_pr_heads "${branch}")" || return 1
  tip="$(git rev-parse "refs/heads/${branch}")"
  if grep -qx "${tip}" <<< "${heads}"; then
    echo "gone"
  else
    echo "stale"
  fi
}

# Collect first, delete after: the ref walk must not race its own deletions.
# A branch checked out in any worktree cannot be deleted, so skip it rather
# than queue a guaranteed failure.
candidates=()
reasons=()
stale=()
while IFS=$'\t' read -r branch track worktree; do
  if [[ -z "${branch}" || -n "${worktree}" || "${branch}" == "${current_branch}" ]]; then
    continue
  fi
  if is_protected "${branch}"; then
    continue
  fi
  reason="$(landed_reason "${branch}" "${track}")" || continue
  if [[ "${reason}" == "stale" ]]; then
    stale+=("${branch}")
    log "Kept ${branch}: upstream gone but tip is not the head of a merged PR"
    continue
  fi
  candidates+=("${branch}")
  reasons+=("${reason}")
done < <(git for-each-ref refs/heads --format='%(refname:short)%09%(upstream:track)%09%(worktreepath)')

if [[ ${#candidates[@]} -eq 0 && ${#stale[@]} -eq 0 ]]; then
  log "No merged branches to clean up"
  exit 0
fi

# -D rather than -d: ancestry or a pruned upstream already proves the work
# landed; -d additionally demands ancestry of HEAD, which fails from a feature
# branch and always fails after a squash merge.
deleted=()
failed=()
for ((i = 0; i < ${#candidates[@]}; i++)); do
  branch="${candidates[$i]}"
  reason="${reasons[$i]}"
  if out="$(git branch -D "${branch}" 2>&1)"; then
    deleted+=("${branch} (${reason})")
    log "Deleted ${branch} (${reason})"
  else
    failed+=("${branch}")
    log "Failed to delete ${branch}: ${out}"
  fi
done

# The ${arr[@]+...} expansion keeps an empty array from tripping set -u on
# bash 3.2.
parts=()
if [[ ${#deleted[@]} -gt 0 ]]; then
  parts+=("Deleted merged local branches: $(join_by ', ' ${deleted[@]+"${deleted[@]}"})")
fi
if [[ ${#failed[@]} -gt 0 ]]; then
  parts+=("Could not delete: $(join_by ', ' ${failed[@]+"${failed[@]}"})")
fi
if [[ ${#stale[@]} -gt 0 ]]; then
  parts+=("Kept, upstream gone but not the head of a merged PR: $(join_by ', ' ${stale[@]+"${stale[@]}"})")
fi
message="$(join_by '; ' ${parts[@]+"${parts[@]}"})"
printf '{"systemMessage": "%s"}\n' "$(json_escape "${message}")"
