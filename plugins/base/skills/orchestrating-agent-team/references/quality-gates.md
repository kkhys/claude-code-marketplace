# Quality Gates with Hooks

Use hooks to enforce standards automatically when teammates complete work.

## TeammateIdle Hook

Runs when a teammate is about to go idle. Exit code 2 sends feedback and keeps the teammate working.

### Run Tests Before Idle

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/check-teammate-tests.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

Script example:

```bash
#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
teammate_name=$(echo "$input" | jq -r '.teammate_name // empty')

# Check if tests pass for files the teammate modified
changed_files=$(git diff --name-only HEAD)

if [ -z "$changed_files" ]; then
  exit 0
fi

# Run tests related to changed files
if ! npm test -- --findRelatedTests $changed_files 2>&1; then
  echo "Tests failed for changes by $teammate_name. Fix before going idle." >&2
  exit 2
fi

exit 0
```

### Lint Check Before Idle

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/check-teammate-lint.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
set -euo pipefail

changed_files=$(git diff --name-only HEAD | grep -E '\.(ts|tsx|js|jsx)$' || true)

if [ -z "$changed_files" ]; then
  exit 0
fi

if ! npx eslint $changed_files 2>&1; then
  echo "Lint errors found. Fix before going idle." >&2
  exit 2
fi

exit 0
```

## TaskCompleted Hook

Runs when a task is being marked complete. Exit code 2 prevents completion and sends feedback.

### Validate Task Deliverables

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/validate-task.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
task_description=$(echo "$input" | jq -r '.task_description // empty')

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes found. Stage and verify before completing task." >&2
  exit 2
fi

# Check tests pass
if ! npm test 2>&1; then
  echo "Tests failing. Fix before marking task complete." >&2
  exit 2
fi

exit 0
```

### Prompt-Based Validation

For more nuanced checks, use a prompt hook:

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Review if this task is truly complete. Check: 1) All requirements met 2) Tests exist for new code 3) No TODO comments left 4) Code follows project conventions. If incomplete, explain what's missing.",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

## Setup

Add hooks to one of:
- `~/.claude/settings.json` (user-scoped)
- `.claude/settings.json` (project-scoped)
- `.claude/settings.local.json` (local only)

## Combining Multiple Gates

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/check-teammate-tests.sh",
            "timeout": 120
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/check-teammate-lint.sh",
            "timeout": 60
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/validate-task.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

All hooks in a matcher run sequentially. If any exits with code 2, the action is blocked and feedback is sent.
