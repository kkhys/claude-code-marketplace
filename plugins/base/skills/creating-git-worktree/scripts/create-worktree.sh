#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

# Usage: show_usage
# Description: Display usage information
show_usage() {
    echo "Usage: $SCRIPT_NAME <branch-name>"
    echo "Example: $SCRIPT_NAME feature/new-feature"
    exit 1
}

# Usage: main <branch-name>
# Description: Create git worktree and setup environment
main() {
    local branch_name="${1:?Error: branch name required}"
    local worktree_name
    local worktree_path
    local repo_root
    local base_branch

    worktree_name=$(echo "$branch_name" | tr '/' '-')
    repo_root=$(git rev-parse --show-toplevel)
    worktree_path="$repo_root/.git-worktrees/$worktree_name"

    echo "Creating worktree for branch: $branch_name"
    echo "Worktree path: $worktree_path"

    cd "$repo_root"

    # Get default branch and sync
    base_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
    git checkout "$base_branch"
    git pull

    # Create worktrees directory
    mkdir -p "$repo_root/.git-worktrees"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo ""
        echo "Worktree already exists at: $worktree_path"
        echo ""
        echo "Next steps:"
        echo "1. cd $worktree_path"
        echo "2. Continue working on your task"
        echo ""
        exit 0
    fi

    # Create worktree (existing or new branch)
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git worktree add "$worktree_path" "$branch_name"
    else
        git worktree add -b "$branch_name" "$worktree_path"
    fi

    # Copy environment files
    if [ -f "$repo_root/.env" ]; then
        cp "$repo_root/.env" "$worktree_path/.env"
        echo "Copied .env file to worktree"
    fi

    if [ -f "$repo_root/.serena" ]; then
        cp "$repo_root/.serena" "$worktree_path/.serena"
        echo "Copied .serena file to worktree"
    fi

    cd "$worktree_path"

    echo ""
    echo "Worktree created successfully!"
    echo ""
    echo "Next steps:"
    echo "1. cd $worktree_path"
    echo "2. Start working on your task"
    echo ""
}

# Validate arguments
if [ $# -eq 0 ]; then
    show_usage
fi

main "$@"
