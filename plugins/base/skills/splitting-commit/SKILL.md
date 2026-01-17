---
name: splitting-commit
description: Split large changes into logical commits by semantic meaning. Use when handling large features or refactors that should be split into focused commits.
---

# Split Commit Workflow

Split large changes into logical commits organized by semantic meaning. This ensures each commit represents a single, cohesive unit of work.

## Workflow Steps

1. **Analyze Changes**
   - Run `git status` to identify all modified, added, and deleted files
   - Run `git diff` to review the full scope of changes
   - Group files by their semantic purpose (features, fixes, refactors, docs, etc.)

2. **Identify Semantic Groups**
   - Group related changes together logically
   - Ensure each group has a clear, single purpose
   - Consider dependencies between groups (e.g., fix before feature that uses it)

3. **Interactive Selection**
   - For each semantic group, use `git add <files>` to stage relevant files
   - Review staged changes with `git diff --cached`
   - **Invoke `formatting-commit` skill** to create properly formatted commit
   - Repeat for each semantic group

4. **Commit Creation**
   For each semantic group, use the `formatting-commit` skill to ensure Conventional Commits compliance.
   The skill provides detailed guidance on commit format, types, and best practices.

## Best Practices

- **One concern per commit**: Each commit should represent a single logical unit
- **Atomic changes**: Commits should be testable and deployable independently
- **Clear messages**: Messages should explain why, not just what
- **Logical ordering**: Commits should flow from foundation to features
- **Test verification**: Each commit should pass tests independently

## Example Workflow

Given changes across auth, API, and docs:

1. **First commit** - `fix(auth): handle token expiration`
2. **Second commit** - `feat(api): add user profile endpoint`
3. **Third commit** - `docs(api): add authentication guide`
4. **Fourth commit** - `refactor(core): extract validation utilities`

## Common Patterns

### Feature with tests
```
feat(feature): implement new functionality
test(feature): add unit tests for new feature
```

### Bug fix with docs
```
fix(bug): resolve issue with edge case
docs(bug): document expected behavior
```

### Refactor with improvements
```
refactor(module): extract shared logic
perf(module): optimize performance after refactoring
```
