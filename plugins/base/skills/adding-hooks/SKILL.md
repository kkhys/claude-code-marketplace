---
name: adding-hooks
description: Add and configure Claude Code hooks for event-driven automation. Use when setting up hooks, creating hook scripts, or automating tool-related workflows.
---

# Claude Code Hooks Configuration

## Quick Start

**First, ask the user where to add hooks**:
- `~/.claude/settings.json` - User-scoped (personal, all projects)
- `.claude/settings.json` - Project-scoped (shared via git)
- `.claude/settings.local.json` - Local project (not committed)
- Plugin `hooks/hooks.json` - Plugin-bundled hooks

## Basic Structure

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolPattern",
        "hooks": [
          {
            "type": "command",
            "command": "your-command-here",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

## Hook Events

| Event | When | Common Use |
|-------|------|------------|
| `PreToolUse` | Before tool execution | Validation, blocking |
| `PostToolUse` | After tool completion | Formatting, logging |
| `PermissionRequest` | Permission dialog shown | Auto-approve/deny |
| `UserPromptSubmit` | User sends prompt | Context injection |
| `Stop` | Agent finishes | Task completion check |
| `SubagentStop` | Subagent finishes | Subagent validation |
| `SessionStart` | Session begins | Environment setup |
| `SessionEnd` | Session ends | Cleanup tasks |
| `Notification` | Notification sent | Alerts |
| `PreCompact` | Before compact | Custom summarization |

See [events.md](references/events.md) for detailed event documentation.

## Matchers

**For PreToolUse, PostToolUse, PermissionRequest**:
- Exact match: `"Write"` - matches Write tool only
- Regex: `"Edit|Write"` - matches Edit or Write
- All tools: `"*"` or `""` or omit matcher
- MCP tools: `"mcp__server__tool"` pattern

**Case-sensitive**: `Write` ≠ `write`

## Hook Types

### Command Hooks

```json
{
  "type": "command",
  "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/check.sh",
  "timeout": 30
}
```

### Prompt Hooks (LLM evaluation)

```json
{
  "type": "prompt",
  "prompt": "Evaluate if Claude should stop: $ARGUMENTS. Check if all tasks complete.",
  "timeout": 30
}
```

Supported for: `Stop`, `SubagentStop`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`

## Exit Codes

| Code | Meaning | Behavior |
|------|---------|----------|
| 0 | Success | Continue execution |
| 2 | Block | Block tool/prompt, show stderr to Claude |
| Other | Non-blocking error | Show stderr, continue |

## Common Patterns

### Auto-format on Write/Edit

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/format.sh"
          }
        ]
      }
    ]
  }
}
```

### Validate Bash Commands

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/validate-bash.sh"
          }
        ]
      }
    ]
  }
}
```

### Inject Context on Prompt

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo \"Current time: $(date)\""
          }
        ]
      }
    ]
  }
}
```

### Protect Files

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/protect-files.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Parse fields with jq
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
tool_input=$(echo "$input" | jq -r '.tool_input // empty')

# Validation logic here

# Exit 0: success, Exit 2: block with stderr message
exit 0
```

See [scripts.md](references/scripts.md) for script examples.

## JSON Output (Advanced)

For structured control, output JSON to stdout (exit code 0):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved"
  }
}
```

See [json-output.md](references/json-output.md) for complete schema.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_PROJECT_DIR` | Project root directory |
| `CLAUDE_PLUGIN_ROOT` | Plugin directory (plugins only) |
| `CLAUDE_ENV_FILE` | Env file path (SessionStart only) |
| `CLAUDE_CODE_REMOTE` | `"true"` if remote environment |

## Security Best Practices

1. **Quote variables**: `"$VAR"` not `$VAR`
2. **Validate input**: Don't trust stdin blindly
3. **Block path traversal**: Check for `..` in paths
4. **Use absolute paths**: Full script paths
5. **Skip sensitive files**: Avoid `.env`, `.git/`, keys

## Debugging

```bash
# Check registered hooks
/hooks

# Debug mode for execution details
claude --debug
```

Common issues:
- Unescaped quotes in JSON: Use `\"`
- Wrong matcher case: `Write` not `write`
- Missing executable permission: `chmod +x script.sh`

## Resources

- [events.md](references/events.md) - Detailed event documentation
- [scripts.md](references/scripts.md) - Hook script examples
- [json-output.md](references/json-output.md) - JSON output schema
