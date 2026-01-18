---
name: suggesting-branch-name
description: Analyzes git changes and suggests branch names following naming conventions. Use when creating new branches from current changes or when asking for branch name suggestions.
---

# Branch Name Suggestion

Analyze git changes (commits and uncommitted changes) to suggest appropriate branch names.

## Naming Convention

### Format

```
<type>/<description>
```

### Types

| Type | Usage |
|------|-------|
| `feature/` | New feature |
| `fix/` | Bug fix |
| `refactor/` | Refactoring |
| `docs/` | Documentation |
| `style/` | Code style / design |
| `chore/` | Miscellaneous / config |

### Description Rules

- English, concise
- Start with verb (`add-`, `update-`, `remove-`, `fix-`)
- Kebab-case (hyphen-separated)
- Prioritize clarity over brevity

### Examples

```
feature/add-contact-form
fix/spelling-error-in-footer
refactor/user-controller
docs/update-readme
chore/update-dependencies
```

## Workflow

### Step 1: Analyze Changes

Run these commands to understand changes:

```bash
# Check current branch
git branch --show-current

# View uncommitted changes
git status --short

# View diff of uncommitted changes
git diff --stat

# View staged changes
git diff --cached --stat

# View recent commits (if on a feature branch)
git log --oneline -10
```

### Step 2: Determine Type

Based on changes:

| Changes | Type |
|---------|------|
| New files, new functionality | `feature/` |
| Bug corrections | `fix/` |
| Code restructuring without behavior change | `refactor/` |
| README, comments, docs | `docs/` |
| Formatting, CSS | `style/` |
| Config, dependencies, tooling | `chore/` |

### Step 3: Generate Description

1. Identify the **main purpose** of changes
2. Start with a **verb**: add, update, remove, fix, implement, refactor
3. Keep it **short but clear** (2-4 words ideal)
4. Use **kebab-case**

### Step 4: Suggest Branch Name

Present suggestion in this format:

```
Suggested branch name: <type>/<description>

Reason: <brief explanation of why this name fits the changes>
```

## Anti-patterns

Avoid these names:

```
# Too vague
test
fix1
branch2
update
changes

# Missing type prefix
add-login
user-feature

# Wrong case
feature/Add_Login
feature/addLogin
```

## Decision Tree

```
Changes include new functionality?
├─ Yes → feature/
└─ No
    ├─ Fixing a bug? → fix/
    ├─ Only docs/README? → docs/
    ├─ Only formatting/style? → style/
    ├─ Restructuring code? → refactor/
    └─ Config/tooling? → chore/
```

## Interactive Mode

If changes are ambiguous, ask user:

1. What is the main purpose of these changes?
2. Is this a new feature or modification?
3. Are there any specific keywords to include?

Then suggest 2-3 options with explanations.
