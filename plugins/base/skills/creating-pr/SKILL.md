---
name: creating-pr
description: Create GitHub pull requests with standardized title format and draft status. Use when the user requests to create a PR (e.g., "PRを作成して", "create a PR", "make a pull request"). This skill uses gh command to create PRs with specific title format '[base-branch] type: description' and generates concise bullet-point descriptions from git changes.
---

# PR Creator

## Overview

Create GitHub pull requests following a standardized format with proper Conventional Commits types and draft status.

## PR Creation Workflow

### 1. Analyze Current State

Check the current branch and merge target:

```bash
# Get current branch
git branch --show-current

# Check remote tracking and base branch
git status
```

### 2. Gather Change Information

Collect information about the changes:

```bash
# Get commit history from base branch
git log origin/main..HEAD --oneline

# Get detailed diff from base branch
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
```

Replace `origin/main` with the actual base branch (e.g., `origin/master`, `origin/develop`).

### 3. Analyze Changes and Determine Type

Analyze the changes and determine the appropriate Conventional Commits type:

- Read [commit-types.md](references/commit-types.md) for detailed type selection guidelines
- Consider the primary purpose of the changes
- Follow the priority order: feat > fix > perf > refactor > test > docs > chore

### 4. Create PR Title

Format: `[base-branch] type: description`

**Components:**
- `[base-branch]`: The target branch name (e.g., `main`, `master`, `develop`)
- `type`: Conventional Commits type (feat, fix, chore, docs, refactor, test, perf, style, ci, build)
- `description`: Concise summary of changes in lowercase

**Examples:**
- `[main] feat: add user authentication system`
- `[main] fix: resolve null pointer in login handler`
- `[develop] refactor: extract validation logic`

### 5. Create PR Description

Generate a concise bullet-point list of main changes:

**Format:**
```markdown
- Main change 1
- Main change 2
- Main change 3
```

**Guidelines:**
- Focus on user-facing or significant technical changes
- Keep each point concise (one line)
- Limit to 3-5 main points
- Use imperative mood (e.g., "Add", "Fix", "Update")

**Example:**
```markdown
- Add JWT authentication middleware
- Implement user login and logout endpoints
- Add password hashing with bcrypt
```

### 6. Create Draft PR

Use `gh` command to create the draft PR:

```bash
gh pr create \
  --title "[main] feat: add user authentication" \
  --body "- Add JWT authentication middleware
- Implement user login and logout endpoints
- Add password hashing with bcrypt" \
  --draft
```

**Important:**
- Always use `--draft` flag to create draft PR
- Use heredoc for multi-line body if needed:

```bash
gh pr create \
  --title "[main] feat: add user authentication" \
  --body "$(cat <<'EOF'
- Add JWT authentication middleware
- Implement user login and logout endpoints
- Add password hashing with bcrypt
EOF
)" \
  --draft
```

## Common Scenarios

### Scenario 1: Feature Branch to Main

**User Request:** "PRを作成して"

**Workflow:**
1. Current branch: `feature/user-auth`
2. Base branch: `main`
3. Changes: Added authentication system
4. Type: `feat`
5. Title: `[main] feat: add user authentication system`
6. Description:
   - Add JWT authentication middleware
   - Implement login/logout endpoints
   - Add bcrypt password hashing

### Scenario 2: Bugfix Branch to Main

**User Request:** "create a PR"

**Workflow:**
1. Current branch: `bugfix/null-pointer`
2. Base branch: `main`
3. Changes: Fixed null pointer exception
4. Type: `fix`
5. Title: `[main] fix: resolve null pointer in login handler`
6. Description:
   - Add null check before accessing user object
   - Add error handling for missing credentials

### Scenario 3: Multiple Types of Changes

**User Request:** "make a pull request"

**Workflow:**
1. Current branch: `feature/api-improvements`
2. Base branch: `develop`
3. Changes: New endpoint + refactoring + tests
4. Type: `feat` (primary purpose is new functionality)
5. Title: `[develop] feat: add data export endpoint`
6. Description:
   - Add CSV export endpoint
   - Refactor data processing logic
   - Add integration tests

## Type Selection Reference

For detailed guidelines on selecting the appropriate type, see [commit-types.md](references/commit-types.md).

**Quick Reference:**
- **feat**: New features or functionality
- **fix**: Bug fixes
- **refactor**: Code restructuring
- **test**: Test additions
- **docs**: Documentation only
- **chore**: Maintenance tasks
- **perf**: Performance improvements
- **style**: Code style/formatting
- **ci**: CI/CD changes
- **build**: Build system changes
