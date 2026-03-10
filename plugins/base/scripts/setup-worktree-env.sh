#!/usr/bin/env bash

set -euo pipefail

# WorktreeCreate hook: replaces default git worktree behavior
# Creates worktree AND copies environment files
# Input: JSON on stdin with "name" and "cwd" fields
# Output: absolute path to the created worktree on stdout

INPUT="$(cat)"
NAME="$(echo "${INPUT}" | jq -r '.name')"
CWD="$(echo "${INPUT}" | jq -r '.cwd')"

WORKTREE_DIR="${CWD}/.claude/worktrees/${NAME}"
BRANCH="worktree-${NAME}"

mkdir -p "$(dirname "${WORKTREE_DIR}")"

# Create git worktree with a new branch based on HEAD
git -C "${CWD}" worktree add -b "${BRANCH}" "${WORKTREE_DIR}" HEAD >&2

# Copy environment files to the new worktree
readonly FILES_TO_COPY=(
  ".env"
  ".env.local"
  ".serena"
)

for file in "${FILES_TO_COPY[@]}"; do
  src="${CWD}/${file}"
  dst="${WORKTREE_DIR}/${file}"

  if [[ -f "${src}" ]] && [[ ! -f "${dst}" ]]; then
    cp "${src}" "${dst}"
    echo "Copied ${file} to worktree" >&2
  fi
done

# Output the worktree path (required by WorktreeCreate hook)
echo "${WORKTREE_DIR}"
