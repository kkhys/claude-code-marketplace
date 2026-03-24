---
name: formatting-commit
description: Enforce Conventional Commits format for git commits. Always consult this skill when committing code changes — including "commit", "コミット", "コミットして", "変更を記録", "save changes", "stage and commit", asking whether to use feat or fix, deciding between squash and new commit, or any request to record, amend, or finalize changes in git. Contains mandatory project-specific conventions for type/scope format (plugin name as scope), squash-vs-new-commit strategy selection, and message structure that differ from defaults and cannot be inferred without this skill.
allowed-tools: Bash(git:*), Read
---

# Formatting Commit

## Strategy Selection

The goal is a clean, reviewable commit history. Two strategies:

### New Commit (default)

Create a new commit when:
- It's the first commit on the branch
- The change is logically independent from existing commits
- You're building incrementally (model -> API -> UI)

A new commit preserves the narrative of how the work evolved. Each commit should be a self-contained, meaningful unit — something a reviewer can understand in isolation.

### Squash (amend)

Amend the previous commit when:
- The change directly extends or fixes the same work (e.g., addressing review feedback)
- A separate commit would be noise rather than signal (typo fix, forgotten file)

Squashing keeps the history focused on intent rather than process. After amending a pushed commit, use `git push --force-with-lease` — never `--force`.

If the branch has multiple commits that need reorganizing, use the `splitting-commit` skill instead of manual rebase.

## Commit Message Format

```
<type>(<scope>): <description>

[body]

[footer]
```

### Type

Select by the primary intent of the change:

| Type | When to use |
|------|-------------|
| `feat` | New user-facing capability |
| `fix` | Correcting broken behavior |
| `refactor` | Restructuring without behavior change |
| `perf` | Performance improvement |
| `test` | Adding or modifying tests |
| `docs` | Documentation only |
| `style` | Code formatting, whitespace |
| `build` | Build system, dependencies |
| `ci` | CI/CD configuration |
| `chore` | Everything else (version bumps, config) |

When changes span multiple types, pick the dominant one. A feature that includes its tests is `feat`, not `test`.

### Scope

The scope identifies the area of the codebase affected. In this marketplace, use the plugin name:

```
feat(base): add memo command
fix(writing): correct language-editor agent prompt
chore(base): bump version to 0.0.19
```

Omit scope only when the change is truly cross-cutting (e.g., root-level config).

### Subject Line

- Imperative mood, lowercase, no trailing period
- Under 50 characters — if it doesn't fit, the commit may be doing too much
- Describe what the commit does, not how

Good: `add OAuth2 login flow`
Bad: `Added the OAuth2 login flow implementation`

### Body

Optional but valuable for non-trivial changes. Explain why the change was needed — the subject already says what. Wrap at 72 characters.

### Footer

- `Closes #123` to auto-close issues
- `BREAKING CHANGE:` or `!` after type for breaking changes: `feat(api)!: remove legacy endpoint`

## Process

1. Run `git status` and `git log --oneline origin/main..HEAD` to understand the branch state
2. Decide strategy: new commit or squash
3. Stage specific files — be deliberate about what goes in
4. Compose the message and commit
5. Verify with `git log -1 --stat`
