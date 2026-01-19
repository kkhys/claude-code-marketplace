---
name: creating-command
description: Best practices for creating custom slash commands with frontmatter, arguments, bash execution, and file references. Use when creating slash commands.
---

# Custom Slash Command Best Practices

## Quick Start

**First, ask the user**:
- Where to create the command file?
  - `.claude/commands/` (project-scoped, shared via git)
  - `~/.claude/commands/` (user-scoped, personal across all projects)

Then create a `.md` file:
```markdown
---
description: Review code for security vulnerabilities
---

Review this code for:
- SQL injection risks
- XSS vulnerabilities
- Authentication issues
```

## Essential Features

### 1. Frontmatter

See [frontmatter.md](references/frontmatter.md) for complete reference.

```markdown
---
description: Brief, specific description
argument-hint: [arg1] [arg2]
allowed-tools: Bash(git:*), Read, Edit
model: claude-sonnet-4-5-20250929
---
```

### 2. Arguments

**All arguments**: `$ARGUMENTS`
```markdown
Fix issue #$ARGUMENTS following coding standards
```

**Positional**: `$1`, `$2`, etc.
```markdown
---
argument-hint: [pr-number] [priority]
---
Review PR #$1 with priority $2
```

### 3. Bash Execution

Use exclamation mark followed by backtick-quoted bash command (requires `allowed-tools: Bash(...)`)

Syntax: `!backtick` + bash command + `backtick`

Example:
```markdown
---
allowed-tools: Bash(git:*)
---
Status: !backtick git status backtick
Recent: !backtick git log --oneline -5 backtick
```

### 4. File References

Prefix: `@`
```markdown
Review @src/utils/auth.js for security issues
Compare @old-version.ts with @new-version.ts
```

## Best Practices

### DO

**Write specific descriptions**:
```yaml
# ✓ Good
description: Create git commit with Conventional Commits format

# ✗ Bad
description: Git helper
```

**Use argument hints**:
```yaml
argument-hint: [component-name] [type:functional|class]
```

**Scope tools appropriately**:
```yaml
# ✓ Good - specific commands only
allowed-tools: Bash(git add:*), Bash(git commit:*)

# ✗ Bad - too broad
allowed-tools: Bash(*)
```

**Keep commands focused**:
```markdown
# ✓ Good - one clear purpose
Create unit tests for the selected code

# ✗ Bad - multiple unrelated tasks
Create tests, update docs, and refactor code
```

**Include context via bash**:
```markdown
---
allowed-tools: Bash(git:*)
---
Current changes: !backtick git diff HEAD backtick
Create commit message based on changes above
```

### DON'T

**Avoid overly broad permissions**:
```yaml
# ✗ Avoid
allowed-tools: Bash(*), Write, Edit, Read
```

**Don't skip descriptions**:
```markdown
# ✗ Bad - no description
Review this code
```

**Don't mix unrelated tasks**:
```markdown
# ✗ Bad
Run tests, deploy to staging, and update documentation
```

**Don't forget argument hints**:
```markdown
# ✗ Bad - uses $1 but no hint
---
description: Create component
---
Create component: $1

# ✓ Good
---
description: Create component
argument-hint: [component-name]
---
Create component: $1
```

## Common Patterns

See [examples.md](references/examples.md) for detailed examples.

### Git Workflow
```markdown
---
description: Create conventional commit
allowed-tools: Bash(git:*)
---
Changes: !backtick git diff --cached backtick
Status: !backtick git status --short backtick

Create Conventional Commits format message
```

### Code Review
```markdown
---
description: Security-focused code review
---

Review for:
- Input validation
- SQL injection
- XSS prevention
- Auth/authz issues
```

### With Arguments
```markdown
---
description: Fix GitHub issue
argument-hint: [issue-number] [priority]
---

Fix issue #$1 with priority $2
Follow project coding standards
```

## Advanced: Disable Auto-Invocation

Prevent Claude from auto-calling via `Skill` tool:
```yaml
---
description: Destructive operation
disable-model-invocation: true
---
```

Use for:
- Destructive operations
- Commands requiring explicit user confirmation
- Experimental commands

## Quick Reference

| Feature | Syntax | Example |
|---------|--------|---------|
| All args | `$ARGUMENTS` | `Fix #$ARGUMENTS` |
| Positional | `$1`, `$2` | `Review PR #$1` |
| Bash | `!backtick cmd backtick` | `!backtick git status backtick` |
| File ref | `@path` | `@src/main.ts` |

## Resources

- [frontmatter.md](references/frontmatter.md) - Complete frontmatter reference
- [examples.md](references/examples.md) - Practical examples
