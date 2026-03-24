---
name: creating-branch-name
description: Create a git branch with an appropriate name derived from current changes. Use when the user asks to create a branch, name a branch, make a branch for current work, or wants to move changes to a new branch. Also use when changes exist on main/master that should be moved to a feature branch before committing.
allowed-tools: Bash(git:*)
---

# Branch Naming

Analyze the current git state — uncommitted changes, staged files, and recent commits — to generate a branch name that communicates the intent of the work at a glance.

## Why naming matters

A branch name is a communication tool. When a teammate sees `feature/add-oauth-login` in a PR list, they immediately know what it's about without opening it. The name should answer "what kind of change is this?" (the type prefix) and "what does it do?" (the description).

## Convention

Format: `<type>/<description>`

Types:
- `feature/` — New capability or user-facing behavior
- `fix/` — Correcting broken behavior
- `refactor/` — Restructuring without changing behavior
- `docs/` — Documentation only
- `style/` — Visual or formatting changes (CSS, code style)
- `chore/` — Tooling, config, dependencies, CI

Description: English, kebab-case, 2-4 words that capture the main intent. Prefer starting with a verb (add, update, remove, implement, extract) when it reads naturally — but for `fix/` branches, describing the problem (e.g., `pagination-off-by-one`) is often clearer than repeating the verb.

**Example 1:**
Changes: New login form component + auth API integration
Branch: `feature/add-login-authentication`

**Example 2:**
Changes: Fix off-by-one error in pagination
Branch: `fix/pagination-off-by-one`

**Example 3:**
Changes: Move utility functions into shared module
Branch: `refactor/extract-shared-utils`

**Example 4:**
Changes: Update ESLint config + reorder imports + add README section
Branch: `chore/update-eslint-and-cleanup` (mixed changes — name for the dominant intent)

## Process

1. Read the git state (`git status`, `git diff --stat`, `git log` as needed) to understand what changed
2. Identify the dominant intent — if changes span multiple concerns, name for the primary one
3. Pick the type that best fits, generate a clear description
4. If the intent is ambiguous, propose 2-3 candidates with brief reasoning and let the user choose
5. Create the branch with `git checkout -b <name>`

After creation, briefly state the branch name and the reasoning behind it.
