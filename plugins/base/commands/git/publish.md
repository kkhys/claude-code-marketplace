---
description: Complete git workflow - create branch, split commits, and create PR
allowed-tools: Bash(git:*), Bash(gh:*)
model: claude-haiku-4-5
---

**IMPORTANT**: Execute the following skills in sequence:

1. Invoke the `creating-branch-name` skill to create a new branch
2. Invoke the `split-commit` skill to split changes into logical commits
3. Invoke the `creating-pr` skill to create a GitHub pull request

# Publish Workflow

This command executes a complete git workflow from branch creation to PR submission:

## Workflow Steps

1. **Branch Creation**: Analyzes current changes and creates a branch with appropriate naming
2. **Commit Splitting**: Organizes changes into logical, semantic commits
3. **PR Creation**: Creates a GitHub pull request with standardized format

Execute each step in order, waiting for completion before proceeding to the next step.
