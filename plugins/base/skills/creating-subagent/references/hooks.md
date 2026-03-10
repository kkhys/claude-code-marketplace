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

## Hook Input

Hook commands receive input via **stdin as JSON** (not environment variables). For `PreToolUse`/`PostToolUse`, the JSON includes `tool_input` with the tool's parameters.

**Exit codes**:
- `0`: Allow the operation
- `2`: Block the operation (error message via stderr is shown to Claude)

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

The validation script reads JSON from stdin and exits with code 2 to block write operations:

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE)\b' > /dev/null; then
  echo "Blocked: Only SELECT queries are allowed" >&2
  exit 2
fi

exit 0
```

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
          command: "./scripts/validate-readonly-query.sh"
---
```

Validation script (`./scripts/validate-readonly-query.sh`):

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$COMMAND" ]; then exit 0; fi

if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|REPLACE|MERGE)\b' > /dev/null; then
  echo "Blocked: Write operations not allowed. Use SELECT queries only." >&2
  exit 2
fi
exit 0
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
