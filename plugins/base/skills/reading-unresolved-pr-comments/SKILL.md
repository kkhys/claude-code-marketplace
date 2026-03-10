---
name: reading-unresolved-pr-comments
description: Fetches unresolved review comments from a GitHub PR and creates a fix plan. Use when reviewing PR feedback, addressing review comments, or resolving PR discussions.
context: fork
---

# Read Unresolved PR Comments

Fetch unresolved review comments from the current PR and create an actionable fix plan.

## Workflow

### 1. Fetch Unresolved Review Comments

Run the script to retrieve all unresolved review threads via GitHub GraphQL API:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/read-unresolved-pr-comments.sh"
```

The script outputs JSON with:
- PR metadata (number, title, URL, state, author)
- Requested reviewers
- All unresolved threads (path, line, comments with author/body/URL)

**Prerequisites:** The current directory must be a git repo with an open PR on the current branch.

### 2. Create Fix Plan

Analyze the unresolved comments and create a concrete fix plan:

1. **Analyze each comment**:
   - Identify the problem or improvement being requested
   - Understand the reviewer's intent and context
   - Locate the exact code that needs modification

2. **Create the plan**:
   - Break down fixes into concrete, parallelizable units
   - Each unit should be independently actionable
   - Group related comments that affect the same file/function
   - Prioritize by dependency order (changes that other fixes depend on first)

3. **Plan format**:

```markdown
## Fix Plan

### Fix 1: [Brief description]
- **File**: path/to/file.ts
- **Line**: 42
- **Comment**: [Summary of reviewer feedback]
- **Action**: [Specific change to make]

### Fix 2: [Brief description]
- **File**: path/to/other-file.ts
- **Line**: 15
- **Comment**: [Summary of reviewer feedback]
- **Action**: [Specific change to make]
```

## Important Rules

- **Do not auto-resolve comments** - Only the reviewer should resolve their own threads
- **Do not push changes** - Present the plan for user approval first
- **Outdated threads**: Include but flag threads marked as `is_outdated: true` - the code may have already changed
- **Parallel execution**: Design fix units to be independently executable where possible
