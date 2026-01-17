# Hooks Reference

Lifecycle hooks for subagents.

## Hook Types

### In Subagent Frontmatter

Hooks defined in the subagent's frontmatter run only while that subagent is active.

| Event | Matcher Input | Fires When |
|-------|---------------|------------|
| `PreToolUse` | Tool name | Before subagent uses a tool |
| `PostToolUse` | Tool name | After subagent uses a tool |
| `Stop` | (none) | When subagent completes |

### In settings.json

Hooks for subagent lifecycle events in the main session.

| Event | Matcher Input | Fires When |
|-------|---------------|------------|
| `SubagentStart` | Agent type name | Subagent starts execution |
| `SubagentStop` | Agent type name | Subagent completes |

## Frontmatter Hook Examples

### Validate Commands Before Execution

```yaml
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---
```

The validation script inspects `$TOOL_INPUT` and exits non-zero to block write operations.

### Run Linter After File Changes

```yaml
---
name: code-fixer
description: Fix code issues with automatic linting
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/run-linter.sh"
---
```

### Cleanup on Completion

```yaml
---
name: temp-processor
description: Process files with cleanup on completion
hooks:
  Stop:
    - hooks:
        - type: command
          command: "./scripts/cleanup-temp.sh"
---
```

**Note**: `Stop` hooks in frontmatter are automatically converted to `SubagentStop` events.

## settings.json Hook Examples

### Setup/Cleanup for Specific Subagent

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/setup-db-connection.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/cleanup-db-connection.sh" }
        ]
      }
    ]
  }
}
```

### Log All Subagent Activity

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": ".*",
        "hooks": [
          { "type": "command", "command": "echo 'Started: $AGENT_TYPE' >> subagent.log" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": ".*",
        "hooks": [
          { "type": "command", "command": "echo 'Stopped: $AGENT_TYPE' >> subagent.log" }
        ]
      }
    ]
  }
}
```

## Hook Structure

```yaml
hooks:
  EventName:
    - matcher: "regex-pattern"  # Optional, matches against tool name or agent type
      hooks:
        - type: command
          command: "shell command to run"
```

## Environment Variables

Available in hook commands:

| Variable | Description |
|----------|-------------|
| `$TOOL_INPUT` | JSON input to the tool (PreToolUse/PostToolUse) |
| `$TOOL_OUTPUT` | Tool output (PostToolUse only) |
| `$AGENT_TYPE` | Subagent type name (SubagentStart/SubagentStop) |

## Use Cases

### Read-Only Database Access

Ensure subagent can only run SELECT queries:

```yaml
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: |
            if echo "$TOOL_INPUT" | grep -iE 'INSERT|UPDATE|DELETE|DROP|CREATE|ALTER'; then
              echo "Write operations not allowed" >&2
              exit 1
            fi
---
```

### Automatic Formatting

Format code after every edit:

```yaml
---
name: code-writer
description: Write code with automatic formatting
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "npx prettier --write ."
---
```

### Resource Management

Setup and teardown resources:

```yaml
---
name: integration-tester
description: Run integration tests with resource management
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/ensure-test-db.sh"
  Stop:
    - hooks:
        - type: command
          command: "./scripts/cleanup-test-db.sh"
---
```
