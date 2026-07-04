---
name: publishing-pr
description: Complete git workflow — create branch, split commits, and create PR
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
disable-model-invocation: true
---

# Publish Workflow

Execute a complete git workflow from branch creation to PR submission.

## Current Changes

- Branch: !`git branch --show-current`
- Status: !`git status --short`

If there are no uncommitted changes and no unpushed commits, report that there is nothing to publish and stop.

## Workflow Steps

Invoke the following skills in sequence, waiting for each to complete before proceeding:

1. `creating-branch-name` — Analyze current changes and create a branch with appropriate naming (skip if already on a feature branch)
2. `splitting-commit` — Organize changes into logical, semantic commits
3. `creating-pr` — Create a GitHub pull request with the standardized format
