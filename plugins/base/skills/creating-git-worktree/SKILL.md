---
name: creating-git-worktree
description: Creates isolated git worktree environments for parallel development. Fetches latest from default branch, creates worktree in .git-worktrees/, copies .env and .serena files. Branch '/' is converted to '-'. Use when starting new features or switching context.
---

# Create Git Worktree Environment

Automate worktree creation with environment setup for parallel development workflows.

## Quick Start

Execute the script with your branch name:

```bash
bash skills/creating-git-worktree/scripts/create-worktree.sh <branch-name>
```

**Example**:
```bash
bash skills/creating-git-worktree/scripts/create-worktree.sh feature/user-auth
# Creates: .git-worktrees/feature-user-auth
```

## What the Script Does

1. **Sync with remote**: Checkout and pull default branch
2. **Create worktree**: In `.git-worktrees/<branch-name>` (new or existing branch)
3. **Copy environment files**: `.env`, `.serena` if they exist
4. **Reuse existing**: Skip creation if worktree already exists

## Branch Name Handling

- `/` is converted to `-` for directory names
- `feature/new-feature` becomes `.git-worktrees/feature-new-feature`
