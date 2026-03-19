---
name: creating-pr
description: Create GitHub pull requests following required project conventions. Always consult this skill when creating a PR, opening a pull request, or submitting changes for review — including "PR作って", "プルリクエスト作成", "create a PR", "make a pull request", "submit for review", "gh pr create", or any request to prepare changes for review on GitHub. Contains mandatory title format [base-branch] type: description, required --draft flag, and --assignee kkhys that differ from defaults and cannot be inferred without this skill.
context: fork
---

# Creating PR

## Title Format

```
[base-branch] type: description
```

The base branch name goes in brackets, followed by a Conventional Commits type and a lowercase description. This format makes it immediately clear where the PR targets and what kind of change it is when scanning a PR list.

**Examples:**
- `[main] feat: add user authentication system`
- `[develop] fix: resolve null pointer in login handler`
- `[main] refactor: extract validation logic`

## Type Selection

When changes span multiple types, select by primary purpose:

feat > fix > perf > refactor > test > docs > style > ci > build > chore

A feature branch that includes bug fixes and tests is still `feat`. A bug fix with some refactoring is still `fix`. Choose the type that captures the main intent.

## PR Template

Before generating a description, check if the repository has a PR template (`.github/pull_request_template.md` or similar standard locations). If found, use it as the body structure and fill in sections based on the actual changes. If multiple templates exist, ask the user which to use.

## Body

When no template exists, write a concise bullet-point list (3-5 items) of the main changes in imperative mood ("Add", "Fix", "Update"). Focus on what matters — user-facing changes and significant technical decisions.

## Base Branch

Use `--base <branch>` to explicitly set the merge target. Determine the base branch from:
1. User's explicit instruction (e.g., "develop にマージ")
2. The branch the current branch was created from
3. Default to `main`

The base branch name also goes into the title brackets: `[develop] fix: ...`

## Required Flags

Always use these flags with `gh pr create`:

- `--draft` — All PRs start as drafts. This gives the author a chance to self-review before requesting reviews.
- `--assignee kkhys` — Always assign to kkhys.

## After Creation

Print the PR URL returned by `gh pr create` so the user can open it directly.
