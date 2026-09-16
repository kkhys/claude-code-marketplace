---
name: creating-branch-name
description: Create a git branch with an appropriate name derived from current changes, following the <type>/<description> convention.
when_to_use: >-
  Trigger when the user asks to create a branch, name a branch, make a branch
  for current work, or move changes to a new branch. Also when changes exist
  on main/master that should be moved to a feature branch before committing.
allowed-tools:
  - Bash(git:*)
---

# Branch Naming

Derive a branch name from the current changes.

## Current Git State

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Diff summary: !`git diff HEAD --stat`
- Recent commits: !`git log --oneline -5`

## Convention

Format: `<type>/<description>`

Types, as full words: `feature/`, `fix/`, `refactor/`, `docs/`, `style/`
(visual or formatting), `chore/` (tooling, config, dependencies, CI).

Description: English, kebab-case, 2–4 words for the main intent. Start with
a verb when it reads naturally (`feature/add-login-authentication`,
`refactor/extract-shared-utils`); for `fix/` the problem itself is often
clearer (`fix/pagination-off-by-one`). Mixed changes are named for the
dominant intent.

## Process

1. Read the injected state; run `git diff` only if it is not enough
2. Pick the type and description; when the intent is genuinely ambiguous,
   propose two or three candidates and let the user choose
3. `git checkout -b <name>`, then state the name and the reasoning in one line
