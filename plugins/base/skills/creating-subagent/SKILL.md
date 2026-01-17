---
name: creating-subagent
description: Guides creation of custom subagents with YAML frontmatter, system prompts, tool restrictions, and permission modes. Use when creating or configuring subagents.
---

# Custom Subagent Creation Guide

## Quick Start

**First, ask the user**:
- Where to create the subagent file?
  - `.claude/agents/` (project-scoped, shared via git)
  - `~/.claude/agents/` (user-scoped, personal across all projects)

Then create a `.md` file:
```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

## Essential Structure

### YAML Frontmatter (Required)

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier (lowercase, hyphens) |
| `description` | Yes | When Claude delegates to this subagent |
| `tools` | No | Allowed tools (inherits all if omitted) |
| `disallowedTools` | No | Tools to deny |
| `model` | No | `sonnet`, `opus`, `haiku`, or `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `skills` | No | Skills to inject at startup |
| `hooks` | No | Lifecycle hooks for this subagent |

See [frontmatter.md](references/frontmatter.md) for complete reference.

### System Prompt (Body)

The markdown body becomes the subagent's system prompt. Include:
1. Role definition
2. Invocation behavior
3. Workflow steps
4. Output format

## Best Practices

### DO

**Write specific descriptions** (Claude uses this for delegation):
```yaml
# Good
description: Expert code reviewer. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.

# Bad
description: Reviews code
```

**Restrict tools appropriately**:
```yaml
# Good - read-only reviewer
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit

# Bad - too permissive for a reviewer
tools: Read, Write, Edit, Bash
```

**Specify model based on task complexity**:
```yaml
# Fast exploration
model: haiku

# Complex analysis
model: sonnet

# Consistent with main conversation
model: inherit
```

**Include clear workflow steps**:
```markdown
When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately
```

### DON'T

**Don't use bypassPermissions carelessly**:
```yaml
# Dangerous - use only when necessary
permissionMode: bypassPermissions
```

**Don't make descriptions vague**:
```yaml
# Bad
description: Helps with code
```

**Don't forget to restrict tools for read-only agents**:
```yaml
# Bad - reviewer shouldn't have Write/Edit
name: code-reviewer
tools: Read, Write, Edit, Grep
```

## Common Patterns

### Read-Only Reviewer

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code clarity and readability
- Proper error handling
- No exposed secrets
- Input validation
- Performance considerations

Provide feedback by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)
```

### Debugger (with Edit access)

```markdown
---
name: debugger
description: Debugging specialist for errors, test failures, and unexpected behavior. Use proactively when encountering issues.
tools: Read, Edit, Bash, Grep, Glob
---

You are an expert debugger specializing in root cause analysis.

When invoked:
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate the failure location
4. Implement minimal fix
5. Verify solution works

For each issue, provide:
- Root cause explanation
- Evidence supporting diagnosis
- Specific code fix
- Prevention recommendations
```

### Domain Expert

```markdown
---
name: data-scientist
description: Data analysis expert for SQL queries, BigQuery operations, and data insights. Use proactively for data analysis tasks.
tools: Bash, Read, Write
model: sonnet
---

You are a data scientist specializing in SQL and BigQuery analysis.

When invoked:
1. Understand the data analysis requirement
2. Write efficient SQL queries
3. Use BigQuery CLI tools (bq) when appropriate
4. Analyze and summarize results
5. Present findings clearly

Key practices:
- Write optimized SQL with proper filters
- Include comments explaining complex logic
- Format results for readability
- Provide data-driven recommendations
```

## Advanced: Hooks

Define lifecycle hooks within the subagent:

```yaml
---
name: code-reviewer
description: Review code changes with automatic linting
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-command.sh $TOOL_INPUT"
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/run-linter.sh"
---
```

See [hooks.md](references/hooks.md) for details.

## Quick Reference

| Feature | Syntax | Example |
|---------|--------|---------|
| Name | lowercase, hyphens | `code-reviewer` |
| Tools (allow) | `tools: A, B, C` | `tools: Read, Grep` |
| Tools (deny) | `disallowedTools: X` | `disallowedTools: Write, Edit` |
| Model | `model: alias` | `model: haiku` |
| Permission | `permissionMode: mode` | `permissionMode: plan` |

## Resources

- [frontmatter.md](references/frontmatter.md) - Complete frontmatter reference
- [hooks.md](references/hooks.md) - Lifecycle hooks reference
- [examples.md](references/examples.md) - More practical examples
