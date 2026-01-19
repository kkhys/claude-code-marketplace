# JSON Output Schema

Hook scripts can return structured JSON to stdout (exit code 0) for advanced control.

## Common Fields

All hook types support:

```json
{
  "continue": true,
  "stopReason": "Reason for stopping",
  "suppressOutput": false,
  "systemMessage": "Warning message"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `continue` | boolean | If `false`, Claude stops after hook |
| `stopReason` | string | Shown to user when `continue: false` |
| `suppressOutput` | boolean | Hide from verbose mode |
| `systemMessage` | string | Warning shown to user |

## PreToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved",
    "updatedInput": {
      "file_path": "/new/path"
    }
  }
}
```

| Field | Values | Effect |
|-------|--------|--------|
| `permissionDecision` | `"allow"` | Bypass permission, execute |
| | `"deny"` | Block execution, reason shown to Claude |
| | `"ask"` | Show permission dialog |
| `permissionDecisionReason` | string | Explanation |
| `updatedInput` | object | Modify tool parameters |

## PermissionRequest

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": { "command": "npm run lint" }
    }
  }
}
```

For deny:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "deny",
      "message": "Not allowed",
      "interrupt": true
    }
  }
}
```

## PostToolUse

```json
{
  "decision": "block",
  "reason": "Lint errors found",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Details for Claude"
  }
}
```

| Field | Effect |
|-------|--------|
| `decision: "block"` | Prompt Claude with `reason` |
| `additionalContext` | Add context for Claude |

## UserPromptSubmit

Block prompt:
```json
{
  "decision": "block",
  "reason": "Blocked: contains sensitive data"
}
```

Add context:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Current time: 2024-01-15 10:30"
  }
}
```

Note: Plain text stdout (non-JSON) also adds context.

## Stop / SubagentStop

```json
{
  "decision": "block",
  "reason": "Tests not passing. Please fix before stopping."
}
```

| Field | Effect |
|-------|--------|
| `decision: "block"` | Prevent stop, Claude continues |
| `reason` | Required when blocking, shown to Claude |

## SessionStart

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Project uses TypeScript 5.0"
  }
}
```

## Prompt Hooks Response

For `type: "prompt"` hooks, LLM must return:

```json
{
  "ok": true,
  "reason": "All tasks complete"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | `true` allows, `false` blocks |
| `reason` | string | Required if `ok: false` |
