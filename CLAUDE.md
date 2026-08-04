# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin marketplace that provides custom skills and workflows. The marketplace enables installation of plugins containing skills (knowledge bundles, also invocable as `/skill-name`), hooks (event automation), and MCP server configurations. Custom slash commands have been merged into skills — this marketplace no longer uses `commands/` directories.

## Architecture

### Marketplace Structure

```
.claude-plugin/
  marketplace.json          # Marketplace metadata and plugin registry
.github/workflows/
  validate.yml              # CI: manifest validation + shellcheck
plugins/
  {plugin-name}/
    .claude-plugin/
      plugin.json          # Plugin metadata, userConfig, component paths
    skills/                # Skills (SKILL.md + references/ + scripts/)
    hooks/                 # Event hooks (hooks.json)
    scripts/               # Shell scripts for automation
    agents/                # Custom subagent definitions (.md files)
    .mcp.json             # MCP server configuration
```

Components that exist in the plugin spec but are unused here: `workflows/` (Workflow scripts), `monitors/`, `themes/`, `.lsp.json`, and `dependencies`. Add them only when there is a concrete need.

Both manifests carry a `$schema` for editor autocomplete; `claude plugin validate` ignores it at load time.

### Plugin Anatomy

**Skills** (`skills/*/SKILL.md`): Knowledge bundles and workflows for specialized tasks. Custom slash commands are merged into skills — every skill is invocable as `/plugin-name:skill-name`, and skills replace the legacy `commands/*.md` files.
- Frontmatter: `name`, `description` (recommended), `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `background`, `hooks`, `paths`, `shell` (all optional)
- `description` + `when_to_use` combined is truncated at 1,536 chars — front-load the primary use case in `description`, put trigger phrases in `when_to_use`
- `allowed-tools` accepts a space-separated string or YAML list (prefer YAML list)
- Body supports `$ARGUMENTS` / `$N` / `$name` substitution and `` !`cmd` `` dynamic context injection (runs before Claude sees the content)
- Also substitutable in the body: `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}`
- Skills with `disable-model-invocation: true` never expose their description to Claude — keep it short (it only appears in the `/` menu)
- `context: fork` runs the skill in a subagent (optionally with `agent:`) — only for self-contained tasks; forked skills cannot see conversation history, ask the user questions, spawn subagents, or create agent teams
- Forked skills default to `background: true`. Set `background: false` whenever the caller needs the result in the same turn (orchestrated steps, required first steps of another workflow)
- References: 1-level deep only (`references/*.md`)
- Keep body under 500 lines (Claude already knows general practices)

**Hooks** (`hooks/hooks.json`): Event-driven automation
- Around 30 events are available. Session: `SessionStart`, `Setup`, `SessionEnd`, `ConfigChange`, `CwdChanged`, `InstructionsLoaded`, `FileChanged`. Prompt/tool: `UserPromptSubmit`, `UserPromptExpansion`, `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`. Output: `Notification`, `MessageDisplay`, `Stop`, `StopFailure`. Agents/tasks: `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`. Worktrees: `WorktreeCreate`, `WorktreeRemove`. Context: `PreCompact`, `PostCompact`. MCP: `Elicitation`, `ElicitationResult`
- Handler types: `command`, `http`, `mcp_tool`, `prompt`, `agent`
- Common handler fields: `type`, `if`, `timeout`, `statusMessage`. Command handlers add `command`, `args`, `async`, `asyncRewake`, `shell`
- Prefer exec form (`command` + `args`) over shell form — no shell tokenization, and path placeholders are substituted verbatim. Use shell form only for pipes and redirects
- Mark long-running, non-blocking handlers `async: true` so they do not stall the turn
- Matchers only apply to tool events; omit `matcher` on `Stop`, `Notification`, `WorktreeCreate`, and similar

**Agents** (`agents/*.md`): Custom subagent definitions
- Frontmatter: `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation` (only valid value: `worktree`)
- `hooks`, `mcpServers`, and `permissionMode` are not supported in plugin-shipped agents for security reasons
- Specialized agents for specific task domains

**MCP Servers** (`.mcp.json`): External tool integrations
- HTTP servers: `type: "http"`, `url`
- Stdio/command servers: `command`, `args`
- Never hardcode machine-specific paths or secrets — declare them in `plugin.json` `userConfig` and reference as `${user_config.KEY}`
- Hooks targeting a bundled server use the scoped tool name `mcp__plugin_<plugin>_<server>__<tool>`

### Key Design Principles

1. **Progressive Disclosure**: Main file (SKILL.md) contains essentials, reference files contain details
2. **Brevity Over Completeness**: Only document what Claude doesn't already know
3. **Skill-Based Workflow**: Skills are directly discoverable by Claude and invocable as slash commands; user-driven workflows use `disable-model-invocation: true` instead of a separate command file
4. **Conventional Commits**: All commits follow `<type>[scope]: <description>` format
5. **Standardized PRs**: Format `[base-branch] type: description` with bullet-point body

## Common Commands

### Validation

```bash
# Validate the marketplace manifest (--strict turns warnings into errors)
claude plugin validate . --strict

# Validate each plugin manifest — the marketplace check does not cover these
claude plugin validate ./plugins/base --strict
claude plugin validate ./plugins/writing --strict

# Within Claude Code
/plugin validate .
```

### Linting

```bash
# ShellCheck for bash scripts (must exit 0 — CI enforces this)
shellcheck plugins/base/scripts/*.sh plugins/base/skills/*/scripts/*.sh
```

CI (`.github/workflows/validate.yml`) runs both of the above on every push and pull request.

### Local Testing

```bash
# Add marketplace locally
/plugin marketplace add ./path/to/claude-code-marketplace

# Install plugin
/plugin install base@my-marketplace

# Test a user-invoked skill
/creating-memo "Test memo content"
```

### Git Workflow

```bash
# Complete git workflow - branch creation, commit split, PR creation
/publishing-pr
```

Note: Individual git operations (formatting-commit, splitting-commit, creating-branch-name, creating-pr) are skills that Claude invokes directly when relevant; `/publishing-pr` orchestrates them in sequence.

## Development Workflow

### Adding New Skills

1. Create directory: `plugins/{plugin}/skills/{skill-name}/`
2. Create `SKILL.md` with frontmatter (`name`, `description`)
3. Keep main content under 500 lines, move details to `references/*.md` (1 level only)
4. Test with different models (Haiku, Sonnet, Opus)
5. Skills are directly discoverable by Claude — no wrapper command needed

### Adding User-Driven Workflow Skills

Slash commands are merged into skills — do not create `commands/*.md` files. For workflows the user triggers explicitly (script execution, multi-skill orchestration):

1. Create a normal skill directory: `plugins/{plugin}/skills/{skill-name}/`
2. Set `disable-model-invocation: true` so only the user can invoke it via `/skill-name`
3. Use `argument-hint` and `$ARGUMENTS` for input, `` !`cmd` `` for dynamic context
4. Bundle scripts under the skill (`scripts/`) and reference them via `${CLAUDE_SKILL_DIR}`
5. If the skill uses `context: fork`, decide `background` deliberately — `false` when a caller needs the result in the same turn
6. Validate: `/plugin validate .`

### Adding New Scripts

1. Create scripts used by a single skill in `plugins/{plugin}/skills/{skill-name}/scripts/` (reference via `${CLAUDE_SKILL_DIR}`); create scripts shared by hooks in `plugins/{plugin}/scripts/` (reference via `${CLAUDE_PLUGIN_ROOT}`)
2. Use bash shebang: `#!/usr/bin/env bash`
3. Set strict mode: `set -euo pipefail`
4. Quote all variables: `"${var}"`
5. Use `readonly` for constants
6. Make executable: `chmod +x script.sh`

### Modifying Base Plugin

The `base` plugin (`plugins/base/`) is the primary plugin containing core workflows:

**User-driven skills** (`disable-model-invocation: true`, invoked via `/skill-name`):
- `creating-memo` - Timestamped memo with ULID in `~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/`
- `publishing-pr` - Complete git workflow: branch creation → commit split → PR creation
- `creating-codepen-demo` - Create CodePen demos
- `creating-task-summary` - Create weekly task summaries
- `uploading-knowledge-gist` - Upload session knowledge to secret GitHub Gist
- `digging` - Interrogate a plan, design, or decision one question at a time until shared understanding is reached

**Model-invocable skills** (discovered by Claude, also invocable via `/skill-name`):

Git workflow:
- `formatting-commit` - Conventional Commits format
- `splitting-commit` - Split commits by semantic meaning
- `creating-branch-name` - Create branch with appropriate naming
- `creating-pr` - GitHub PR creation
- `creating-stacked-pr` - Verify whether a task should be split into stacked PRs, design layers, build the stack with gh-stack

PR review:
- `reading-unresolved-pr-comments` - Fetch unresolved PR review comments and create fix plan
- `resolving-pr-comments` - Bulk-resolve all unresolved review threads on current PR
- `fixing-review-comments` - Address unresolved review comments on the current branch
- `posting-pr-review` - Post review comments to a GitHub PR as a PENDING review

Other:
- `summarizing-release-notes` - Summarize recent Claude Code release notes

**Agents**:
- `general-purpose-assistant` - Fallback agent for broad inquiries and cross-domain tasks

**MCP Servers** (`plugins/base/.mcp.json`):
- `astro-docs` - Astro documentation search (HTTP)
- `analytics-mcp` - Google Analytics queries. Project ID comes from `userConfig.google_project_id`; auth uses gcloud application default credentials (`gcloud auth application-default login`)
- `chrome-devtools` - Chrome DevTools automation

Other MCP servers used day to day (`context7`, `serena`, `playwright`, and framework-specific ones) come from official plugins or user settings, not from this repository.

When modifying, maintain consistency with existing patterns and update version in `.claude-plugin/plugin.json`.

### Writing Plugin

The `writing` plugin (`plugins/writing/`) provides specialized writing agents:

**Agents**:
- `content-reviewer` - Review content quality
- `language-editor` - Edit language and grammar
- `readability-enhancer` - Improve readability
- `technical-writer` - Technical writing assistance

## Important Patterns

### Skills as the Single Interface

Skills cover both auto-discovery by Claude and explicit `/skill-name` invocation — there is no separate command layer. Choose the invocation mode per skill:
- Model + user invocable (default): knowledge and conventions Claude should apply when relevant (e.g., `formatting-commit`)
- `disable-model-invocation: true`: side-effectful or user-timed workflows (e.g., `/creating-memo`, `/publishing-pr`)
- `user-invocable: false`: background knowledge that is not a meaningful user action

### Skill Description Format

Write skill descriptions in third person with specific invocation triggers:

```yaml
# Good
description: Enforce Conventional Commits format for git commits. Use when creating commits.

# Bad
description: Helps with commits
```

### GitHub Comment Attribution

Every comment posted to GitHub from this marketplace starts with `[from Claude Code]`, so reviewers can tell an agent's comment from the user's own. `reply-to-review-threads.sh` and `post-pr-review.sh` prepend it idempotently — write bodies without it. Add it by hand when posting with plain `gh pr comment`.

### Tool Restrictions

Scope `allowed-tools` narrowly to prevent overly broad permissions:

```yaml
# Good
allowed-tools:
  - Bash(git:*)
  - Read

# Bad
allowed-tools:
  - Bash(*)
  - Read
  - Write
  - Edit
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
