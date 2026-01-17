---
name: formatting-commit
description: Enforce Conventional Commits format for git commits. Use when creating commits.
---

# Conventional Commits

Apply Conventional Commits specification to all git commits.

## Commit Workflow

When creating commits:

1. Run `git status` and `git diff` to analyze changes
2. Review recent commits (`git log`) to match project style
3. Select appropriate type and optional scope
4. Draft message: `<type>[scope]: <description>` (imperative, lowercase, no period, ~50 chars)
5. Add body if complex (explain why, not what)
6. Add exclamation mark after scope or `BREAKING CHANGE:` footer for breaking changes
7. Add footers: `Closes #123`, `Refs: #456`, etc.
8. Commit using heredoc format

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`

Breaking changes: Append exclamation mark after the scope (example: feat(api)!: description) or add `BREAKING CHANGE:` footer.

## Examples

```bash
feat(auth): add OAuth2 login flow
fix: resolve timezone handling in date picker
docs(readme): correct installation command
refactor(config)!: migrate to YAML format

BREAKING CHANGE: JSON config no longer supported.
```
