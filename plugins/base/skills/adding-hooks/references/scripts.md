# Hook Script Examples

## Basic Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Read JSON input
input=$(cat)

# Parse with jq
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Your logic here

# Exit codes:
# 0 = success, continue
# 2 = block, stderr shown to Claude
# other = non-blocking error
exit 0
```

## Bash Command Validator

Block dangerous bash commands:

```bash
#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ "$tool_name" != "Bash" ]] && exit 0
[[ -z "$command" ]] && exit 0

# Block rm -rf on root
if [[ "$command" =~ rm[[:space:]]+-rf?[[:space:]]+/ ]]; then
  echo "Blocked: dangerous rm command" >&2
  exit 2
fi

# Block sudo
if [[ "$command" =~ ^sudo ]]; then
  echo "Blocked: sudo commands require manual execution" >&2
  exit 2
fi

exit 0
```

## File Protection

Protect specific files from modification:

```bash
#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ -z "$file_path" ]] && exit 0

# Protected patterns
protected=(
  ".env"
  ".env.local"
  "secrets.json"
  "credentials.json"
)

for pattern in "${protected[@]}"; do
  if [[ "$file_path" == *"$pattern"* ]]; then
    echo "Protected file: $pattern" >&2
    exit 2
  fi
done

exit 0
```

## Auto-Format Code

Run formatter after file writes:

```bash
#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ -z "$file_path" ]] && exit 0
[[ ! -f "$file_path" ]] && exit 0

case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx)
    npx prettier --write "$file_path" 2>/dev/null || true
    ;;
  *.py)
    black "$file_path" 2>/dev/null || true
    ;;
  *.go)
    gofmt -w "$file_path" 2>/dev/null || true
    ;;
esac

exit 0
```

## Context Injection (UserPromptSubmit)

Add context to every prompt:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Add current git branch
branch=$(git branch --show-current 2>/dev/null || echo "not a git repo")
echo "Current branch: $branch"

# Add recent commits
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Recent commits:"
  git log --oneline -3 2>/dev/null || true
fi

exit 0
```

## Environment Setup (SessionStart)

Set up environment on session start:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install dependencies if needed
if [[ -f "package.json" ]] && [[ ! -d "node_modules" ]]; then
  npm install >/dev/null 2>&1 || true
fi

# Persist environment variables
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"

  # Load nvm if available
  if [[ -f "$HOME/.nvm/nvm.sh" ]]; then
    source "$HOME/.nvm/nvm.sh"
    nvm use --lts >/dev/null 2>&1 || true
  fi
fi

exit 0
```

## Python Example: Validate Commands

```python
#!/usr/bin/env python3
import json
import re
import sys

BLOCKED_PATTERNS = [
    (r"\brm\s+-rf\s+/", "Dangerous rm command"),
    (r"\bsudo\b", "sudo requires manual execution"),
    (r"\bcurl\b.*\|\s*bash", "Piping curl to bash is blocked"),
]

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)

if data.get("tool_name") != "Bash":
    sys.exit(0)

command = data.get("tool_input", {}).get("command", "")

for pattern, message in BLOCKED_PATTERNS:
    if re.search(pattern, command, re.IGNORECASE):
        print(message, file=sys.stderr)
        sys.exit(2)

sys.exit(0)
```

## Python Example: Auto-Approve Safe Tools

```python
#!/usr/bin/env python3
import json
import sys

SAFE_EXTENSIONS = (".md", ".txt", ".json", ".yaml", ".yml")

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {})

# Auto-approve reading documentation files
if tool_name == "Read":
    file_path = tool_input.get("file_path", "")
    if file_path.endswith(SAFE_EXTENSIONS):
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "Safe file type"
            }
        }
        print(json.dumps(output))
        sys.exit(0)

sys.exit(0)
```
