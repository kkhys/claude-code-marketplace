---
name: cleaning-workspace
description: Delete every local branch of the current repository except the protected ones, after showing the list once
argument-hint: "[--keep <branch>...]"
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
---

# Cleaning the Workspace

Reset the checkout to trunk only: no extra branches. The Stop hook already
deletes merged branches; this is for the rest — abandoned experiments and
stacks whose PRs were squash-merged. Worktrees are Orca's to create and
remove, so this skill never touches one or the branch it has checked out.

## Current state

- Branch: !`git branch --show-current`
- Branches (with the worktree that has each checked out): !`git branch --format='%(refname:short)%09%(worktreepath)'`

## Process

1. Protected: `main`, `master`, `develop`, `staging`, `production`, every
   branch checked out in a worktree (the current one included), and every
   name after `--keep` in `$ARGUMENTS`.
2. List what will go — every other branch — and flag the ones that hold
   work nowhere else: commits missing from the branch's upstream, or no
   upstream at all (`git log --oneline <branch>@{upstream}..<branch>`).
   Ask once; `-D` destroys that work.
3. On yes: `git branch -D <branch> ...`
4. Report what was removed and what was kept, one line each.
