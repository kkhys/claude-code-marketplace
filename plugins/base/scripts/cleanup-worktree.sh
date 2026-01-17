#!/usr/bin/env bash

set -euo pipefail

# Usage: get_default_branch
# Description: Get the default branch name from remote
# Returns: Default branch name (e.g., "main", "master")
get_default_branch() {
    git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
}

# Usage: is_protected_branch <branch-name>
# Description: Check if branch is protected (main, master, develop)
# Returns: 0 if protected, 1 otherwise
is_protected_branch() {
    local branch="${1}"
    echo "$branch" | grep -qE '^(main|master|develop)$'
}

# Usage: has_uncommitted_changes <worktree-path>
# Description: Check if worktree has uncommitted changes
# Returns: 0 if has changes, 1 otherwise
has_uncommitted_changes() {
    local worktree_path="${1}"
    [ -n "$(git -C "$worktree_path" status --porcelain 2>/dev/null)" ]
}

# Usage: is_merged <branch-name> <default-branch>
# Description: Check if branch is merged to default branch
# Returns: 0 if merged, 1 otherwise
is_merged() {
    local branch="${1}"
    local default_branch="${2}"
    git branch --merged "$default_branch" | sed 's/^[*+ ]*//' | grep -qx "$branch"
}

# Usage: has_commits <branch-name> <default-branch>
# Description: Check if branch has commits beyond merge base
# Returns: 0 if has commits, 1 otherwise
has_commits() {
    local branch="${1}"
    local default_branch="${2}"
    local branch_point
    local branch_head

    branch_point=$(git merge-base "$default_branch" "$branch" 2>/dev/null || true)
    branch_head=$(git rev-parse "$branch" 2>/dev/null || true)

    if [ -z "$branch_point" ] || [ -z "$branch_head" ]; then
        return 1
    fi

    [ "$branch_point" != "$branch_head" ]
}

# Usage: has_worktree <branch-name>
# Description: Check if branch has associated worktree
# Returns: 0 if has worktree, 1 otherwise
has_worktree() {
    local branch="${1}"
    local result

    result=$(git worktree list --porcelain | awk -v branch="$branch" '
        /^worktree / { path = substr($0, 10) }
        /^branch / {
            ref = substr($0, 8)
            if (ref == "refs/heads/" branch) {
                print "yes"
                exit
            }
        }
    ')

    [ -n "$result" ]
}

# Usage: cleanup_merged_worktrees <default-branch>
# Description: Remove merged worktrees
cleanup_merged_worktrees() {
    local default_branch="${1}"
    local worktree_path
    local branch

    echo "Cleaning up merged worktrees..."

    while IFS= read -r line; do
        worktree_path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | awk '{print $3}' | sed 's/^\[//' | sed 's/\]$//')

        if [ -z "$branch" ] || [ "$branch" = "(bare)" ]; then
            continue
        fi

        if is_protected_branch "$branch"; then
            continue
        fi

        if ! has_commits "$branch" "$default_branch"; then
            echo "Skipping '$branch' - no commits yet"
            continue
        fi

        if ! is_merged "$branch" "$default_branch"; then
            echo "Skipping '$branch' - not merged to $default_branch"
            continue
        fi

        if has_uncommitted_changes "$worktree_path"; then
            echo "Skipping '$branch' - has uncommitted changes"
            continue
        fi

        echo "Removing merged worktree: $worktree_path ($branch)"
        git worktree remove "$worktree_path"
    done < <(git worktree list | tail -n +2)
}

# Usage: cleanup_merged_branches <default-branch>
# Description: Remove merged branches without worktrees
cleanup_merged_branches() {
    local default_branch="${1}"
    local merged_branches
    local branch

    echo "Cleaning up merged branches without worktrees..."

    merged_branches=$(git branch --merged "$default_branch" | sed 's/^[*+ ]*//' | grep -v -E '^(main|master|develop)$' || true)

    if [ -z "$merged_branches" ]; then
        echo "No merged branches to clean up"
        return
    fi

    while IFS= read -r branch; do
        if has_worktree "$branch"; then
            continue
        fi

        echo "Deleting merged branch: $branch"
        git branch -d "$branch"
    done <<< "$merged_branches"
}

# Usage: main
# Description: Main entry point
main() {
    local repo_root
    local default_branch

    repo_root=$(git rev-parse --show-toplevel)
    cd "$repo_root"

    echo "Fetching remote updates..."
    git fetch --prune

    default_branch=$(get_default_branch)
    readonly default_branch

    echo "Default branch: $default_branch"

    cleanup_merged_worktrees "$default_branch"
    cleanup_merged_branches "$default_branch"

    echo "Done."
}

# Error handling
trap 'echo "Error on line $LINENO" >&2' ERR

main "$@"
