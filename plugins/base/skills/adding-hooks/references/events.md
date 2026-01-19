# Hook Events Reference

## PreToolUse

Runs after Claude creates tool parameters, before tool execution.

**Common matchers**: `Task`, `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`, `WebFetch`, `WebSearch`

**Input**:
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/dir",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "/path", "content": "..." },
  "tool_use_id": "toolu_01ABC..."
}
```

**Control**: Can allow, deny, or ask permission. Can modify tool input via `updatedInput`.

## PostToolUse

Runs immediately after tool completes successfully.

**Input**: Same as PreToolUse plus `tool_response` field.

**Control**: Can provide feedback to Claude via `decision: "block"` and `reason`.

## PermissionRequest

Runs when permission dialog is shown to user.

**Matchers**: Same as PreToolUse

**Control**: Can auto-allow or deny permissions programmatically.

## UserPromptSubmit

Runs when user submits a prompt, before Claude processes it.

**Input**:
```json
{
  "session_id": "abc123",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "User's prompt text"
}
```

**Control**:
- stdout (exit 0) adds context
- `decision: "block"` prevents processing

## Stop

Runs when main Claude agent finishes. Not triggered on user interrupts.

**Input**:
```json
{
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
```

`stop_hook_active: true` means Claude is already continuing from a stop hook. Check this to prevent infinite loops.

**Control**: `decision: "block"` with `reason` makes Claude continue working.

## SubagentStop

Runs when a Task tool (subagent) finishes.

Same structure as Stop.

## SessionStart

Runs when Claude Code starts or resumes a session.

**Matchers**: `startup`, `resume`, `clear`, `compact`

**Input**:
```json
{
  "hook_event_name": "SessionStart",
  "source": "startup"
}
```

**Special**: Access `CLAUDE_ENV_FILE` to persist environment variables:
```bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
fi
```

## SessionEnd

Runs when session ends. Cannot block session end.

**Input**:
```json
{
  "hook_event_name": "SessionEnd",
  "reason": "exit"
}
```

`reason`: `clear`, `logout`, `prompt_input_exit`, `other`

## Notification

Runs when Claude Code sends notifications.

**Matchers**: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`

**Input**:
```json
{
  "hook_event_name": "Notification",
  "message": "Notification text",
  "notification_type": "permission_prompt"
}
```

## PreCompact

Runs before compact operation.

**Matchers**: `manual` (from `/compact`), `auto` (context window full)

**Input**:
```json
{
  "hook_event_name": "PreCompact",
  "trigger": "manual",
  "custom_instructions": ""
}
```
