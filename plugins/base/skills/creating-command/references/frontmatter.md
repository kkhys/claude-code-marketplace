# Frontmatter Reference

YAML metadata for slash command configuration.

## Basic Structure

```markdown
---
key: value
---

Command content...
```

## Available Fields

### `description`

Brief description shown in `/help` and autocomplete.

```yaml
description: Create git commit with conventional format
```

**Best practices**:
- Be specific and concise
- Include what it does and when to use it
- Avoid vague terms like "helper" or "utility"

### `argument-hint`

Shows expected arguments in autocomplete.

```yaml
# Simple
argument-hint: [file-path]

# Multiple
argument-hint: [source] [destination]

# With alternatives
argument-hint: add [tagId] | remove [tagId] | list

# Complex
argument-hint: [pr-number] [priority:high|medium|low] [assignee]
```

### `allowed-tools`

Tools permitted for this command.

```yaml
# Single tool
allowed-tools: Bash(git:*)

# Multiple (comma-separated)
allowed-tools: Bash(git:*), Read, Edit

# Multiple (list)
allowed-tools:
  - Bash(git:*)
  - Bash(npm:*)
  - Read
  - Write
```

**Common patterns**:
```yaml
# Git operations
allowed-tools: Bash(git:*)

# Package managers
allowed-tools: Bash(npm:*), Bash(pnpm:*)

# File operations
allowed-tools: Read, Write, Edit

# Specific git commands
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git status:*)
```

### `model`

Specific model for this command.

```yaml
# Balanced (default)
model: claude-sonnet-4-5-20250929

# Most capable
model: claude-opus-4-5-20251101

# Fastest, economical
model: claude-3-5-haiku-20241022
```

**When to specify**:
- Haiku: Simple, quick tasks
- Opus: Complex reasoning
- Sonnet: Balanced (default)

### `disable-model-invocation`

Prevent auto-invocation via `Skill` tool.

```yaml
disable-model-invocation: true
```

**Use for**:
- Destructive operations
- Commands requiring explicit confirmation
- Experimental features

### `hooks`

Execute scripts during command execution.

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
          once: true
```

**Hook types**:
- `PreToolUse`: Before tool execution
- `PostToolUse`: After tool execution
- `Stop`: When command completes

**Options**:
- `once: true`: Run once per session, then remove

## Complete Examples

### Minimal
```markdown
---
description: Review code for bugs
---

Review this code for bugs and suggest fixes.
```

### With Arguments
```markdown
---
description: Fix GitHub issue
argument-hint: [issue-number]
---

Fix issue #$ARGUMENTS following coding standards.
```

### With Tools
```markdown
---
description: Create git commit
allowed-tools: Bash(git:*)
---

Status: !\`git status\`
Create commit for staged changes.
```

### Advanced
```markdown
---
description: Deploy to staging
argument-hint: [version]
allowed-tools: Bash(git:*), Bash(npm:*)
model: claude-sonnet-4-5-20250929
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/pre-deploy-check.sh"
          once: true
---

Version: $1
Branch: !\`git branch --show-current\`

Deploy version $1 to staging.
```

### Production-Safe
```markdown
---
description: Database migration
argument-hint: [migration-name]
allowed-tools: Bash(npm run migrate:*)
disable-model-invocation: true
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/backup-db.sh"
          once: true
---

Run migration: $ARGUMENTS

**WARNING**: Affects production database.
Automatic backup will run before migration.
```

## Validation Tips

**YAML syntax**:
```yaml
# ✗ Wrong - missing quotes
description: Review: security check

# ✓ Correct
description: "Review: security check"
```

**Tool patterns**:
```yaml
# ✗ Wrong - too broad
allowed-tools: Bash(*)

# ✓ Correct
allowed-tools: Bash(git:*)
```

**Argument hints with usage**:
```yaml
# ✗ Wrong - uses $1 but no hint
---
description: Create component
---
Create: $1

# ✓ Correct
---
description: Create component
argument-hint: [component-name]
---
Create: $1
```

## Quick Reference

| Field | Purpose | Example |
|-------|---------|---------|
| `description` | Command description | `Create git commit` |
| `argument-hint` | Argument guidance | `[pr-number] [priority]` |
| `allowed-tools` | Tool permissions | `Bash(git:*), Read` |
| `model` | Specific model | `claude-3-5-haiku-20241022` |
| `disable-model-invocation` | Prevent auto-call | `true` |
| `hooks` | Script execution | See examples above |
