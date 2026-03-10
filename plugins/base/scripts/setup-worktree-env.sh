#!/usr/bin/env bash

set -euo pipefail

# WorktreeCreate hook: overrides Claude Code's default worktree creation
# Creates worktree AND copies environment files
# Cleanup is handled by Claude Code's native ExitWorktree
# Requires: jq
# Input: JSON on stdin with "name" and "cwd" fields
# Output: absolute path to the created worktree on stdout

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

trap 'echo "[Error] ${SCRIPT_NAME} failed on line ${LINENO}" >&2' ERR

if ! command -v jq &>/dev/null; then
  echo "[Error] jq is required but not installed. Install with: brew install jq" >&2
  exit 1
fi

INPUT="$(cat)"
readonly INPUT

if [[ -z "${INPUT}" ]]; then
  echo "[Error] No input received on stdin. Expected JSON with 'name' and 'cwd' fields." >&2
  exit 1
fi

NAME="$(echo "${INPUT}" | jq -r '.name // empty')"
readonly NAME
CWD="$(echo "${INPUT}" | jq -r '.cwd // empty')"
readonly CWD

if [[ -z "${NAME}" ]]; then
  echo "[Error] 'name' field is missing or null in input JSON" >&2
  exit 1
fi

if [[ -z "${CWD}" ]]; then
  echo "[Error] 'cwd' field is missing or null in input JSON" >&2
  exit 1
fi

# Reject path traversal and unsafe characters in NAME
if [[ "${NAME}" == *".."* ]] || [[ "${NAME}" == *"/"* ]]; then
  echo "[Error] 'name' contains unsafe characters (.., /): ${NAME}" >&2
  exit 1
fi

if [[ ! "${NAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "[Error] 'name' must only contain alphanumeric characters, dots, hyphens, and underscores: ${NAME}" >&2
  exit 1
fi

# Resolve repository root to avoid subdirectory issues
REPO_ROOT="$(git -C "${CWD}" rev-parse --show-toplevel)"
readonly REPO_ROOT

WORKTREE_DIR="${REPO_ROOT}/.claude/worktrees/${NAME}"
readonly WORKTREE_DIR
BRANCH="worktree-${NAME}"
readonly BRANCH

# Idempotent: if worktree already exists and is registered, reuse it
if [[ -d "${WORKTREE_DIR}" ]]; then
  if git -C "${REPO_ROOT}" worktree list --porcelain | grep -q "^worktree ${WORKTREE_DIR}$"; then
    echo "[Info] Worktree already exists, reusing: ${WORKTREE_DIR}" >&2
    echo "${WORKTREE_DIR}"
    exit 0
  else
    echo "[Error] Directory exists but is not a registered worktree: ${WORKTREE_DIR}" >&2
    echo "[Info] Remove manually and retry" >&2
    exit 1
  fi
fi

if git -C "${REPO_ROOT}" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "[Error] Branch '${BRANCH}' already exists." >&2
  echo "[Info] Remove the old worktree first: git worktree remove <path> && git branch -d ${BRANCH}" >&2
  exit 1
fi

mkdir -p "$(dirname "${WORKTREE_DIR}")"

# Create git worktree with a new branch based on HEAD
git -C "${REPO_ROOT}" worktree add -b "${BRANCH}" "${WORKTREE_DIR}" HEAD >&2

# Copy environment files and directories to the new worktree
readonly FILES_TO_COPY=(
  ".env"
  ".env.local"
  ".serena"
)

for file in "${FILES_TO_COPY[@]}"; do
  src="${REPO_ROOT}/${file}"
  dst="${WORKTREE_DIR}/${file}"

  if [[ -e "${src}" ]] && [[ ! -e "${dst}" ]]; then
    cp -r "${src}" "${dst}"
    echo "[Info] Copied ${file} to worktree" >&2
  fi
done

# Output the worktree path (required by WorktreeCreate hook)
echo "${WORKTREE_DIR}"
