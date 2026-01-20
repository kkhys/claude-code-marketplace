#!/usr/bin/env bash
set -euo pipefail

# cleanup-merged-branches.sh
# Interactively cleanup branches that have been merged into main

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

# Get merged branches (bash 3.2+ compatible)
merged_branches=()
while IFS= read -r branch; do
  [[ -n "${branch}" ]] && merged_branches+=("${branch}")
done < <(git branch --merged "${base_branch}" | sed 's/^[* ]*//' || true)

# Filter out protected branches and current branch
branches_to_delete=()
for branch in "${merged_branches[@]}"; do
  # Skip empty lines
  [[ -z "${branch}" ]] && continue
  
  # Skip current branch
  [[ "${branch}" == "${CURRENT_BRANCH}" ]] && continue
  
  # Skip protected branches
  is_protected=false
  for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "${branch}" == "${protected}" ]]; then
      is_protected=true
      break
    fi
  done
  
  [[ "${is_protected}" == true ]] && continue
  
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
echo "" >&2

# Check if running in interactive mode
if [[ -t 0 ]]; then
  # Interactive mode: wait for user confirmation
  echo "[Hook] Press Enter to delete these branches or Ctrl+C to skip..." >&2
  read -r
else
  # Non-interactive mode: wait with timeout
  echo "[Hook] Waiting 10 seconds for confirmation (press Enter to continue, Ctrl+C to skip)..." >&2
  if ! read -r -t 10; then
    echo "[Info] Timeout - skipping branch cleanup" >&2
    exit 0
  fi
fi

# Delete branches
echo "" >&2
echo "[Info] Deleting merged branches..." >&2
for branch in "${branches_to_delete[@]}"; do
  if git branch -d "${branch}" 2>/dev/null; then
    echo "  ✓ Deleted: ${branch}" >&2
  else
    echo "  ✗ Failed to delete: ${branch}" >&2
  fi
done

echo "[Info] Branch cleanup completed" >&2
