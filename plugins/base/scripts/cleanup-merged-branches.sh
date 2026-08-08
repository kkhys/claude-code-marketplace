#!/usr/bin/env bash
set -euo pipefail

# cleanup-merged-branches.sh
# Automatically cleanup branches that have been merged into main.
# Runs on the Stop hook and safely deletes merged local branches (git branch -d).

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

# Protected branches that should never be deleted
readonly PROTECTED_BRANCHES=(
  "main"
  "master"
  "develop"
  "staging"
  "production"
)

# Error handling
trap 'echo "[Error] ${SCRIPT_NAME} failed on line $LINENO" >&2' ERR

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "[Info] Not in a git repository, skipping branch cleanup" >&2
  exit 0
fi

# Get current branch
CURRENT_BRANCH="$(git branch --show-current)"
readonly CURRENT_BRANCH

# Determine the base branch for merged check (prefer main, fallback to master)
base_branch=""
if git show-ref --verify --quiet refs/heads/main; then
  base_branch="main"
elif git show-ref --verify --quiet refs/heads/master; then
  base_branch="master"
else
  echo "[Info] No main or master branch found, skipping branch cleanup" >&2
  exit 0
fi

# Get merged branches (bash 3.2+ compatible). A branch checked out in any
# worktree cannot be deleted, so skip those instead of queueing a guaranteed
# failure.
merged_branches=()
while IFS=$'\t' read -r branch worktree; do
  if [[ -z "${branch}" || -n "${worktree}" ]]; then
    continue
  fi
  merged_branches+=("${branch}")
done < <(git branch --merged "${base_branch}" --format='%(refname:short)%09%(worktreepath)' || true)

# Filter out protected branches and current branch. The ${arr[@]+...}
# expansion keeps an empty array from tripping set -u on bash 3.2.
branches_to_delete=()
for branch in ${merged_branches[@]+"${merged_branches[@]}"}; do
  if [[ "${branch}" == "${CURRENT_BRANCH}" ]]; then
    continue
  fi

  is_protected=false
  for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "${branch}" == "${protected}" ]]; then
      is_protected=true
      break
    fi
  done

  if [[ "${is_protected}" == true ]]; then
    continue
  fi

  branches_to_delete+=("${branch}")
done

# Exit if no branches to delete
if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
  echo "[Info] No merged branches to cleanup" >&2
  exit 0
fi

# Display branches to delete
echo "" >&2
echo "========================================" >&2
echo "Merged branches detected:" >&2
echo "========================================" >&2
for branch in "${branches_to_delete[@]}"; do
  echo "  - ${branch}" >&2
done
echo "========================================" >&2

# Delete branches
echo "" >&2
echo "[Info] Deleting merged branches..." >&2
for branch in "${branches_to_delete[@]}"; do
  # -D rather than -d: the --merged filter above already proves the branch is
  # merged into ${base_branch}; -d would additionally require it to be merged
  # into HEAD and fail whenever the hook fires from a feature branch.
  if result="$(git branch -D "${branch}" 2>&1)"; then
    echo "  ✓ Deleted: ${branch}" >&2
  else
    echo "  ✗ Failed to delete: ${branch}" >&2
    echo "    ${result}" >&2
  fi
done

echo "[Info] Branch cleanup completed" >&2
