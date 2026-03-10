---
name: resolving-pr-comments
description: Resolve all unresolved review threads on the current PR. Use when the user wants to bulk-resolve PR comments after addressing feedback.
context: fork
---

# Resolve PR Comments

Bulk-resolve all unresolved review threads on the current GitHub PR.

## Workflow

### 1. Resolve All Unresolved Threads

Run the script to fetch and resolve all unresolved review threads via GitHub GraphQL API:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/resolve-pr-comments.sh"
```

The script will:
- Fetch all review threads with pagination support
- Identify unresolved threads
- Resolve each thread via the `resolveReviewThread` GraphQL mutation
- Report success/failure for each thread

**Prerequisites:** The current directory must be a git repo with an open PR on the current branch.

## Important Rules

- **Run only when explicitly requested** - Do not auto-resolve without user confirmation
- **No rollback** - Resolved threads cannot be easily unresolved; confirm intent before running
