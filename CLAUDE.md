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
    agents/                # Custom subagent definitions (.md files)
    .mcp.json             # MCP server configuration
```

### Plugin Anatomy

**Commands** (`commands/*.md`): Slash commands with YAML frontmatter
- Frontmatter: `description`, `argument-hint`, `allowed-tools`, `model`, `disable-model-invocation`
- Body supports: `$ARGUMENTS`, `$1`, `$2` (arguments), `!`cmd`` (bash execution), `@path` (file refs)

**Skills** (`skills/*/SKILL.md`): Knowledge bundles for specialized tasks
- Frontmatter: `name`, `description` (recommended), `argument-hint`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `context`, `agent`, `hooks` (all optional)
- References: 1-level deep only (`references/*.md`)
- Keep body under 500 lines (Claude already knows general practices)

**Hooks** (`hooks/hooks.json`): Event-driven automation
- Events: `PreToolUse`, `PostToolUse`, `Notification`, `Stop`
- Actions: Execute shell commands on events

**Agents** (`agents/*.md`): Custom subagent definitions
- Frontmatter: `name`, `description`, `model`
- Specialized agents for specific task domains

**MCP Servers** (`.mcp.json`): External tool integrations
- HTTP servers: `type: "http"`, `url`
- Stdio/command servers: `command`, `args`

### Key Design Principles

1. **Progressive Disclosure**: Main file (SKILL.md) contains essentials, reference files contain details
2. **Brevity Over Completeness**: Only document what Claude doesn't already know
3. **Skill-Based Workflow**: Skills are directly discoverable by Claude; commands are only needed for multi-step workflows or script execution
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
# Complete git workflow - branch creation, commit split, PR creation
/publish-pr
```

Note: Individual git operations (commit, commit-split, create-branch, create-pr) are available as skills that Claude can invoke directly without slash commands.

## Development Workflow

### Adding New Skills

1. Create directory: `plugins/{plugin}/skills/{skill-name}/`
2. Create `SKILL.md` with frontmatter (`name`, `description`)
3. Keep main content under 500 lines, move details to `references/*.md` (1 level only)
4. Test with different models (Haiku, Sonnet, Opus)
5. Skills are directly discoverable by Claude — no wrapper command needed

### Adding New Commands

Only create commands when a skill alone is insufficient (script execution, multi-skill orchestration, argument processing):

1. Create `.md` file in `plugins/{plugin}/commands/`
2. Add YAML frontmatter with `description` and optional `argument-hint`, `allowed-tools`, `model`
3. Write command body using `$ARGUMENTS`, `!`bash``, `@file` syntax
4. Validate: `/plugin validate .`

### Adding New Scripts

1. Create script in `plugins/{plugin}/scripts/`
2. Use bash shebang: `#!/usr/bin/env bash`
3. Set strict mode: `set -euo pipefail`
4. Quote all variables: `"${var}"`
5. Use `readonly` for constants
6. Make executable: `chmod +x script.sh`

### Modifying Base Plugin

The `base` plugin (`plugins/base/`) is the primary plugin containing core workflows:

**Commands**:
- `/memo` - Timestamped memo with ULID in `~/projects/private-content/memo/`
- `/create-worktree` - Create git worktree for parallel development (invokes `creating-git-worktree` skill)
- `/publish-pr` - Complete git workflow: branch creation → commit split → PR creation

**Skills** (invoked directly by Claude without slash commands):
- `creating-command` - Create slash commands
- `creating-skill` - Create skills
- `creating-subagent` - Create subagents
- `creating-codepen-demo` - Create CodePen demos
- `creating-rules` - Create Claude Code rules
- `adding-hooks` - Add and configure hooks
- `creating-task-summary` - Create weekly task summaries
- `formatting-commit` - Conventional Commits format
- `splitting-commit` - Split commits by semantic meaning
- `creating-branch-name` - Create branch with appropriate naming
- `creating-pr` - GitHub PR creation
- `creating-git-worktree` - Create git worktree
- `using-serena` - Codebase analysis with Serena
- `reading-unresolved-pr-comments` - Fetch unresolved PR review comments and create fix plan

**Agents**:
- `general-purpose-assistant` - Fallback agent for broad inquiries and cross-domain tasks

**MCP Servers**:
- `context7` - Documentation search
- `astro-docs`, `vercel`, `next-devtools`, `shadcn`, `playwright` - Framework-specific tools
- `serena` - Codebase analysis

When modifying, maintain consistency with existing patterns and update version in `.claude-plugin/plugin.json`.

### Writing Plugin

The `writing` plugin (`plugins/writing/`) provides specialized writing agents:

**Agents**:
- `content-reviewer` - Review content quality
- `language-editor` - Edit language and grammar
- `readability-enhancer` - Improve readability
- `technical-writer` - Technical writing assistance

## Important Patterns

### Skills as Primary Interface

Skills are directly discoverable and invocable by Claude without needing wrapper commands. Only create commands when:
- The command executes a script directly (e.g., `/memo`)
- The command orchestrates multiple skills in sequence (e.g., `/publish-pr`)
- The command requires argument processing beyond what skills provide

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
