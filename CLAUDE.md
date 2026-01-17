# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin marketplace that provides custom commands, skills, and workflows. The marketplace enables installation of plugins containing slash commands, skills (knowledge bundles), hooks (event automation), and MCP server configurations.

## Architecture

### Marketplace Structure

```
.claude-plugin/
  marketplace.json          # Marketplace metadata and plugin registry
plugins/
  {plugin-name}/
    .claude-plugin/
      plugin.json          # Plugin metadata (name, version, author)
    commands/              # Slash commands (.md files)
    skills/                # Reusable knowledge (SKILL.md + references)
    hooks/                 # Event hooks (hooks.json)
    scripts/               # Shell scripts for automation
    .mcp.json             # MCP server configuration
```

### Plugin Anatomy

**Commands** (`commands/*.md`): Slash commands with YAML frontmatter
- Frontmatter: `description`, `argument-hint`, `allowed-tools`, `model`, `disable-model-invocation`
- Body supports: `$ARGUMENTS`, `$1`, `$2` (arguments), `!`cmd`` (bash execution), `@path` (file refs)

**Skills** (`skills/*/SKILL.md`): Knowledge bundles for specialized tasks
- Frontmatter: `name`, `description` (how Claude discovers and invokes)
- References: 1-level deep only (`references/*.md`)
- Keep body under 500 lines (Claude already knows general practices)

**Hooks** (`hooks/hooks.json`): Event-driven automation
- Events: `PreToolUse`, `PostToolUse`, `Notification`, `Stop`
- Actions: Execute shell commands on events

**MCP Servers** (`.mcp.json`): External tool integrations
- HTTP servers: `type: "http"`, `url`
- Stdio/command servers: `command`, `args`

### Key Design Principles

1. **Progressive Disclosure**: Main file (SKILL.md) contains essentials, reference files contain details
2. **Brevity Over Completeness**: Only document what Claude doesn't already know
3. **Skill-Based Workflow**: Commands invoke skills for complex logic
4. **Conventional Commits**: All commits follow `<type>[scope]: <description>` format
5. **Standardized PRs**: Format `[base-branch] type: description` with bullet-point body

## Common Commands

### Validation

```bash
# Validate marketplace structure and JSON syntax
claude plugin validate .

# Within Claude Code
/plugin validate .
```

### Testing

```bash
# Run all tests with bats-core
bats plugins/base/tests/create-memo.bats

# Run single test
bats plugins/base/tests/create-memo.bats -f "test name pattern"

# Install bats-core (macOS)
brew install bats-core

# Install bats-core (Linux)
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh ~/.local
```

### Linting

```bash
# ShellCheck for bash scripts
shellcheck plugins/base/scripts/*.sh
shellcheck plugins/base/hooks/*.sh
```

### Local Testing

```bash
# Add marketplace locally
/plugin marketplace add ./path/to/claude-code-marketplace

# Install plugin
/plugin install base@my-marketplace

# Test command
/memo "Test memo content"
```

### Git Workflow

```bash
# Create conventional commit (uses formatting-commit skill)
/commit

# Split large changes into logical commits (uses splitting-commit skill)
/commit-split

# Create PR with standardized format (uses creating-pr skill)
/create-pr
```

## Development Workflow

### Adding New Commands

1. Create `.md` file in `plugins/{plugin}/commands/`
2. Add YAML frontmatter with `description` and optional `argument-hint`, `allowed-tools`, `model`
3. Write command body using `$ARGUMENTS`, `!`bash``, `@file` syntax
4. For complex logic, create a skill and invoke it from the command
5. Validate: `/plugin validate .`

### Adding New Skills

1. Create directory: `plugins/{plugin}/skills/{skill-name}/`
2. Create `SKILL.md` with frontmatter (`name`, `description`)
3. Keep main content under 500 lines, move details to `references/*.md` (1 level only)
4. Test with different models (Haiku, Sonnet, Opus)
5. Invoke skill from commands using `**IMPORTANT**: Invoke the \`skill-name\` skill before proceeding.`

### Adding New Scripts

1. Create script in `plugins/{plugin}/scripts/`
2. Use bash shebang: `#!/usr/bin/env bash`
3. Set strict mode: `set -euo pipefail`
4. Quote all variables: `"${var}"`
5. Use `readonly` for constants
6. Add bats tests in `plugins/{plugin}/tests/`
7. Make executable: `chmod +x script.sh`

### Modifying Base Plugin

The `base` plugin (`plugins/base/`) is the primary plugin containing core workflows:

**Commands**:
- `/memo` - Timestamped memo with ULID in `~/projects/private-content/memo/`
- `/create-command` - Create slash commands (invokes `creating-command` skill)
- `/create-skill` - Create skills (invokes `creating-skill` skill)
- `/create-subagent` - Create subagents (invokes `creating-subagent` skill)
- `/commit` - Conventional Commits format (invokes `formatting-commit` skill)
- `/commit-split` - Split commits (invokes `splitting-commit` skill)
- `/create-pr` - GitHub PR creation (invokes `creating-pr` skill)

**MCP Servers**:
- `context7` - Documentation search
- `astro-docs`, `next-devtools`, `shadcn`, `playwright` - Framework-specific tools
- `serena` - Codebase analysis

When modifying, maintain consistency with existing patterns and update version in `.claude-plugin/plugin.json`.

## CI/CD

### Workflows

- **Lint** (`.github/workflows/lint.yml`): ShellCheck on `plugins/base/scripts/**/*.sh` and `plugins/base/hooks/**/*.sh`
- **Test** (`.github/workflows/test.yml`): Bats tests on Ubuntu and macOS

Both run on:
- Push to `main`
- Pull requests
- Manual dispatch

### Test Files

`plugins/base/tests/create-memo.bats` tests the memo creation script:
- Validates ULID generation (26 chars, base32-like charset)
- Verifies frontmatter format (`id`, `createdAt`)
- Checks directory naming (`YYYYMMDD_HHMMSS`)
- Tests multi-line content, special characters, Japanese text, URLs
- Ensures no emoji in output

## Important Patterns

### Command → Skill Invocation

Commands serve as user-facing entry points that immediately invoke skills for complex logic:

```markdown
---
description: Create git commit with Conventional Commits format
---

**IMPORTANT**: Invoke the `formatting-commit` skill before proceeding.

# Commit

Create a git commit following Conventional Commits specification.
```

### Skill Description Format

Write skill descriptions in third person with specific invocation triggers:

```yaml
# Good
description: Enforce Conventional Commits format for git commits. Use when creating commits.

# Bad
description: Helps with commits
```

### Tool Restrictions

Scope `allowed-tools` narrowly to prevent overly broad permissions:

```yaml
# Good
allowed-tools: Bash(git:*), Read

# Bad
allowed-tools: Bash(*), Read, Write, Edit
```

### Heredoc for Multi-line

Use heredoc for complex bash output or multi-line PR bodies:

```bash
git commit -m "$(cat <<'EOF'
feat(auth): add JWT authentication

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

## Notes

- All bash scripts use `set -euo pipefail` for strict error handling
- No package.json - this is a pure plugin marketplace (no npm dependencies)
- MCP servers extend Claude Code capabilities without plugin code changes
- Skills are knowledge bundles, not executable code (use scripts for automation)
- Conventional Commits types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`
- PR title format: `[base-branch] type: description` (e.g., `[main] feat: add authentication`)
