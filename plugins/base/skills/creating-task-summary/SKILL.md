---
name: creating-task-summary
description: Creates a weekly summary of PRs authored by the current user. Use when creating weekly reports, work reviews, or task summaries.
---

# Task Summary Creation

Generate a summary of work completed in the past week based on GitHub PRs.

## Workflow

### 1. Get Current User

```bash
gh api user --jq '.login'
```

### 2. Fetch PRs from Last 7 Days

```bash
gh pr list --author "@me" --state all --search "created:>=$(date -v-7d +%Y-%m-%d)" --json number,title,url,body,mergedAt,state --limit 100
```
### 3. Analyze and Group PRs

Group PRs by:
- Feature area (extracted from PR title prefix or scope)
- Related functionality (based on PR body content)
- Conventional commit type (feat, fix, docs, etc.)

### 4. Output Format

```markdown
## Weekly Work Summary (YYYY-MM-DD - YYYY-MM-DD)

### [Category/Feature Name]
- Brief description of what was accomplished
- Related PRs:
  - [PR Title](PR URL) (merged/open/closed)
  - [PR Title](PR URL) (merged/open/closed)

### [Category/Feature Name]
- Brief description of what was accomplished
- Related PRs:
  - [PR Title](PR URL) (merged/open/closed)
```

## Grouping Guidelines

- **By Conventional Commit Type**:
  - `feat:` - New features
  - `fix:` - Bug fixes
  - `docs:` - Documentation
  - `refactor:` - Code improvements
  - `test:` - Test additions
  - `chore:` - Maintenance tasks

- **By Scope** (if present in PR title):
  - `feat(auth):` - Group under "Authentication"
  - `fix(api):` - Group under "API"

- **By Content**: If no clear pattern, analyze PR body to identify related work

## Notes

- Include all PR states: merged, open, and closed
- Prioritize merged PRs in the summary
- Extract meaningful descriptions from PR bodies, not just titles
- Keep descriptions concise and action-oriented
