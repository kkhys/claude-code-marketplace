---
description: Create git worktree for parallel development
argument-hint: <branch-name>
allowed-tools: Bash(git:*), Read
---

**IMPORTANT**: Invoke the `creating-git-worktree` skill before proceeding.

# Create Worktree

Create an isolated git worktree environment for parallel development.

1. Invoke `creating-git-worktree` skill
2. Execute the worktree creation script with the provided branch name: $ARGUMENTS
3. Report the created worktree path to the user
