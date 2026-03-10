# Frontmatter Reference

Complete reference for subagent YAML frontmatter fields.

## Required Fields

### name

Unique identifier for the subagent.

**Rules**:
- Lowercase letters, numbers, and hyphens only
- Maximum 64 characters
- No XML tags

```yaml
# Good
name: code-reviewer
name: data-scientist
name: db-reader

# Bad
name: Code_Reviewer  # uppercase, underscore
name: my agent       # space
```

### description

Describes when Claude should delegate to this subagent.

**Rules**:
- Maximum 1024 characters
- Write in third person
- Be specific about use cases

```yaml
# Good - specific, actionable
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.

# Good - includes trigger keywords
description: Data analysis expert for SQL queries, BigQuery operations, and data insights. Use proactively for data analysis tasks and queries.

# Bad - too vague
description: Reviews code
description: Helps with data
```

## Optional Fields

### tools

Specifies which tools the subagent can use. If omitted, inherits all tools from main conversation (including MCP tools).

**Available internal tools**:
- `Read` - Read files
- `Write` - Create/overwrite files
- `Edit` - Modify files
- `Grep` - Search file contents
- `Glob` - Find files by pattern
- `Bash` - Execute shell commands
- `Agent` - Spawn subagents (only for main thread agents, not subagents)
- `WebFetch` - Fetch web content
- `WebSearch` - Search the web
- `AskUserQuestion` - Ask clarifying questions

**Note**: `Task(...)` references still work as aliases for `Agent(...)`.

**Restricting subagent spawning** (only for agents running as main thread with `claude --agent`):

```yaml
# Allow spawning only specific subagent types
tools: Agent(worker, researcher), Read, Bash

# Allow spawning any subagent
tools: Agent, Read, Bash

# Omitting Agent entirely prevents spawning any subagents
tools: Read, Grep, Glob
```

```yaml
# Allow specific tools
tools: Read, Grep, Glob, Bash

# Read-only tools
tools: Read, Grep, Glob

# All tools (explicit)
tools: Read, Write, Edit, Grep, Glob, Bash, WebFetch, WebSearch
```

### disallowedTools

Tools to deny, removed from inherited or specified list.

```yaml
# Inherit all but deny Write and Edit
disallowedTools: Write, Edit

# Allow Read, Grep, Glob, Bash but deny Edit
tools: Read, Grep, Glob, Bash, Edit
disallowedTools: Edit
```

### model

The AI model for this subagent.

| Value | Description |
|-------|-------------|
| `sonnet` | Balanced speed and capability |
| `haiku` | Fast, low-latency. Good for exploration |
| `opus` | Most capable. Complex reasoning |
| `inherit` | Same model as main conversation (default) |

```yaml
# Fast exploration
model: haiku

# Complex analysis
model: sonnet

# Most capable
model: opus

# Match main conversation
model: inherit
```

### permissionMode

Controls how the subagent handles permission prompts.

| Mode | Behavior |
|------|----------|
| `default` | Standard permission checks with prompts |
| `acceptEdits` | Auto-accept file edits |
| `dontAsk` | Auto-deny permission prompts (allowed tools still work) |
| `bypassPermissions` | Skip all permission checks (dangerous) |
| `plan` | Plan mode (read-only exploration) |

```yaml
# Standard (default)
permissionMode: default

# Auto-accept edits
permissionMode: acceptEdits

# Read-only exploration
permissionMode: plan

# Use with extreme caution
permissionMode: bypassPermissions
```

**Note**: If parent uses `bypassPermissions`, it takes precedence and cannot be overridden.

### skills

Skills to inject into subagent context at startup. Full skill content is injected, not just made available for invocation.

**Note**: Subagents do not inherit skills from parent conversation.

```yaml
skills:
  - formatting-commit
  - code-style-guide
```

### mcpServers

MCP servers available to this subagent. Each entry is either a server name referencing an already-configured server or an inline definition.

```yaml
# Reference existing server
mcpServers:
  - slack

# Inline definition
mcpServers:
  my-server:
    type: http
    url: https://example.com/mcp
```

### hooks

Lifecycle hooks scoped to this subagent. Hook commands receive input via stdin as JSON. See [hooks.md](hooks.md) for details.

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/lint.sh"
  Stop:
    - hooks:
        - type: command
          command: "./scripts/cleanup.sh"
```

### maxTurns

Maximum number of agentic turns before the subagent stops.

```yaml
maxTurns: 50
```

### memory

Persistent memory scope for cross-session learning. Enables Read/Write/Edit tools automatically.

| Scope | Location | Use when |
|-------|----------|----------|
| `user` | `~/.claude/agent-memory/<name>/` | Knowledge across all projects (recommended default) |
| `project` | `.claude/agent-memory/<name>/` | Project-specific, shareable via git |
| `local` | `.claude/agent-memory-local/<name>/` | Project-specific, not in version control |

```yaml
memory: user
```

When enabled, `MEMORY.md` (first 200 lines) is injected into the subagent's context.

### background

Set to `true` to always run this subagent as a background task.

```yaml
background: true
```

### isolation

Set to `worktree` to run in a temporary git worktree (isolated copy of the repository). Auto-cleaned if no changes are made.

```yaml
isolation: worktree
```

## Complete Example

```yaml
---
name: secure-reviewer
description: Security-focused code reviewer. Proactively analyzes code for vulnerabilities, injection risks, and authentication issues. Use after security-sensitive changes.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
permissionMode: default
maxTurns: 30
memory: project
skills:
  - security-checklist
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly.sh"
---
```
