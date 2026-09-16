---
name: cleaning-workspace
description: Remove every git worktree of the current repository and delete every local branch except the protected ones, after showing the list once
argument-hint: "[--keep <branch>...]"
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
---

# Cleaning the Workspace

Reset the checkout to trunk only: no extra branches, no worktrees. The Stop
hook already deletes merged branches; this is for the rest — abandoned
experiments, stacks whose PRs were squash-merged, worktrees left by other
sessions.

## Current state

- Branch: !`git branch --show-current`
- Worktrees: !`git worktree list`
- Branches: !`git branch --format='%(refname:short)'`

## Process

1. Protected: `main`, `master`, `develop`, `staging`, `production`, the
   current branch, and every name after `--keep` in `$ARGUMENTS`.
2. List what will go — every worktree except the main one, every other
   branch — and flag the ones that hold work nowhere else: a worktree with
   uncommitted changes (`git -C <path> status --short`), a branch with
   commits missing from its upstream or with no upstream at all
   (`git log --oneline @{upstream}..<branch>`). Ask once; `-D` and
   `--force` destroy that work.
3. On yes:

   ```bash
   git worktree remove --force <path>   # each worktree
   git worktree prune
   git branch -D <branch> ...           # each remaining branch
   ```

4. Report what was removed and what was kept, one line each.
