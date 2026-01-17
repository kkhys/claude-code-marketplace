---
name: formatting-commit
description: Commits code changes with appropriate git commit strategy. Adopts Squash (default), new commit, or Interactive Rebase based on context, and creates messages following Conventional Commits format. Use when implementation is complete or user requests a commit.
---

# High Quality Commit

## Step 1: Check Branch State

```bash
git status
git log --oneline --graph origin/main..HEAD
```

## Step 2: Choose Commit Strategy

### Strategy A: Squash (Default)

Squash into existing commit when changes relate to same theme and no reason to split.

```bash
git add -A
git commit --amend
```

### Strategy B: New Commit

Create new commit when it's the first commit, or changes are independent from existing commits.

```bash
git add -A
git commit
```

### Strategy C: Interactive Rebase

Reorganize commit history to group small commits, reorder, or clean up WIP commits.

```bash
git rebase -i origin/main
```

Operations: `pick` (keep), `squash` (merge), `reword` (edit message), `drop` (remove)

## Strategy Selection Flowchart

```
Does branch have commits?
  ├─ No → New commit
  └─ Yes → Same theme as existing commit?
      ├─ Yes → Squash (git commit --amend)
      └─ No → Rational to split?
          ├─ Yes → New commit
          └─ Want to organize history → Interactive Rebase
```

## Step 3: Commit Message

### Format (Conventional Commits)

```
<type>[scope]: <description>

[body]

[footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Add or modify tests
- `docs`: Documentation changes
- `style`: Formatting changes
- `build`: Build-related changes
- `ci`: CI configuration
- `chore`: Other changes

### Guidelines

- **Subject**: Max 50 chars, imperative mood, lowercase start, no period
- **Body (Optional)**: Explain why (not what), wrap at 72 chars
- **Footer (Optional)**: `Closes #123`, `BREAKING CHANGE:` or `feat(api)!:`

### Commit with Heredoc

```bash
git commit -m "$(cat <<'EOF'
feat(auth): add OAuth2 login flow

Implement OAuth2 authentication to support third-party login providers.

Closes #123
EOF
)"
```

## Step 4: Verify After Commit

```bash
git log -1 --stat
git status
```

## Important Notes

1. **Never execute on main branch**: Always work on feature branches
2. **Atomic commits**: Each commit should be independently meaningful
3. **Consistency**: Follow existing project commit style
4. **Force push**: Use `git push --force-with-lease` after amend

## Detailed Guide

See [references/examples.md](references/examples.md) for detailed examples and troubleshooting.
