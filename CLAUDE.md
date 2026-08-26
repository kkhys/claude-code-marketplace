# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin marketplace that provides custom skills and workflows. The marketplace enables installation of plugins containing skills (knowledge bundles, also invocable as `/skill-name`), hooks (event automation), output styles (system-prompt personas), and MCP server configurations. Custom slash commands have been merged into skills — this marketplace no longer uses `commands/` directories.

Claude Code is not the only consumer. The skills are symlinked into `~/.agents/skills` (by the dotfiles nix activation) and read by Codex, Gemini CLI, Cursor, Devin and Copilot CLI from the working tree, and the `mcp` plugin is installed into Codex / Devin / Copilot through the same marketplace format. See "Skills shared with other agents" below for what that constrains.

## Architecture

### Marketplace Structure

```
.claude-plugin/
  marketplace.json          # Marketplace metadata and plugin registry
.github/workflows/
  validate.yml              # CI: manifest validation + shellcheck
plugins/
  base/                    # Skills, hooks, agents, output styles
    .claude-plugin/
      plugin.json          # Plugin metadata, component paths
    skills/                # Skills (SKILL.md + references/ + scripts/ + agents/)
    hooks/                 # Event hooks (hooks.json)
    scripts/               # Shell scripts for automation
    agents/                # Subagent definitions shared across skills (.md files)
    output-styles/         # Output styles (.md files with frontmatter)
  mcp/                     # MCP server configurations only
    .claude-plugin/
      plugin.json
    .mcp.json              # The one canonical MCP server list
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
- Agents used by exactly one skill live under that skill (`skills/{skill}/agents/*.md`) and are registered by listing each file in the manifest's `agents` array (plugin-root-relative paths, additive to `agents/`). Keeps the agent next to the skill that dispatches it; `agents/` stays for agents any skill may use
- Whatever the file's location, the agent is addressed as `{plugin}:{agent-name}` — the directory does not scope the name, so names must stay unique across the plugin

**Output Styles** (`output-styles/*.md`): Persona and register changes applied to the whole session
- Frontmatter: `name` (defaults to the filename), `description` (shown in the `/config` picker), `keep-coding-instructions`, `force-for-plugin`
- A plugin style is registered as `{plugin}:{name}` — that full string is what `/config` shows and what `settings.json` `outputStyle` must match. Omit `name` so the filename carries it and the two stay in sync
- The body is appended to the system prompt verbatim, so every line costs tokens on every session — keep it to rules Claude would not otherwise follow
- `keep-coding-instructions: true` is the default choice here: an output style that only changes register must not drop Claude Code's built-in software-engineering instructions (scoping, comments, verification). Omit it only for a style where Claude is not doing engineering at all
- Leave `force-for-plugin` unset. Setting it applies the style automatically whenever the plugin is enabled and overrides the user's own `outputStyle` setting — never what a personal always-on plugin wants
- `output-styles/` is the default path, so no `outputStyles` entry in `plugin.json` is needed
- Styles are cached per process and the cache is only cleared by plugin lifecycle operations (install/enable/disable, marketplace update). Editing one takes effect in a new session — `/clear` does not reload it

**MCP Servers** (`plugins/mcp/.mcp.json`): External tool integrations, kept in a plugin of their own so that Codex, Devin and Copilot can install the same file and the dotfiles activation can generate Gemini / Cursor configs from it
- HTTP servers: `type: "http"`, `url`
- Stdio/command servers: `command`, `args`
- Never hardcode machine-specific paths or secrets. Non-secret values (a Google Cloud project ID) are written literally: `${user_config.KEY}` and `userConfig` are expanded by Claude Code only, and every other consumer would see the placeholder
- Hooks and `settings.json` permissions address a bundled server by the scoped tool name `mcp__plugin_<plugin>_<server>__<tool>` — for this plugin, `mcp__plugin_mcp_<server>__*`. Renaming a server or moving it between plugins renames its tools

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
claude plugin validate ./plugins/mcp --strict

# Within Claude Code
/plugin validate .
```

### Linting

```bash
# ShellCheck for all bash scripts, including shared libs (must exit 0 — CI enforces this)
find plugins -name '*.sh' -print0 | xargs -0 -r shellcheck

# Syntax check for Python scripts (stdlib only, no install step)
python3 -m compileall -q plugins
```

### Tests

```bash
# Offline tests for the babysitting-pr watcher (terminal rules, state, version gate)
bash plugins/base/skills/babysitting-pr/scripts/test-pr-watch.sh

# Payload validation and attribution-marker tests for the reply script
bash plugins/base/skills/fixing-review-comments/scripts/test-reply-to-review-threads.sh
```

CI (`.github/workflows/validate.yml`) runs manifest validation, ShellCheck, Python syntax checks, and the script tests on pull requests and pushes to `main`. Every `test-*.sh` under `plugins/*/scripts/` and `plugins/*/skills/*/scripts/` is picked up automatically — new test scripts need no CI change.

### Local Testing

```bash
# Add marketplace locally
/plugin marketplace add ./path/to/claude-code-marketplace

# Install plugins
/plugin install base@my-marketplace
/plugin install mcp@my-marketplace

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

1. Create directory: `plugins/{plugin}/skills/{skill-name}/` — `SKILL.md` sits directly in it, never nested deeper
2. Create `SKILL.md` with frontmatter (`name` equal to the directory name, `description`) — both mandatory, see "Skills shared with other agents"
3. Keep main content under 500 lines, move details to `references/*.md` (1 level only)
4. Test with different models (Haiku, Sonnet, Opus)
5. Skills are directly discoverable by Claude — no wrapper command needed
6. If the skill is ported or adapted from another project, record the source, its license, and the derived paths in `THIRD_PARTY_NOTICES.md`

### Adding User-Driven Workflow Skills

Slash commands are merged into skills — do not create `commands/*.md` files. For workflows the user triggers explicitly (script execution, multi-skill orchestration):

1. Create a normal skill directory: `plugins/{plugin}/skills/{skill-name}/`
2. Set `disable-model-invocation: true` so only the user can invoke it via `/skill-name`
3. Use `argument-hint` and `$ARGUMENTS` for input, `` !`cmd` `` for dynamic context
4. Bundle scripts under the skill (`scripts/`) and reference them via `${CLAUDE_SKILL_DIR}`, with the fallback line from "Skills shared with other agents"
5. If the skill uses `context: fork`, decide `background` deliberately — `false` when a caller needs the result in the same turn
6. Validate: `/plugin validate .`

### Adding New Scripts

1. Create scripts used by a single skill in `plugins/{plugin}/skills/{skill-name}/scripts/` (reference via `${CLAUDE_SKILL_DIR}`); create scripts shared by hooks in `plugins/{plugin}/scripts/` (reference via `${CLAUDE_PLUGIN_ROOT}`)
2. Helpers shared across skills live in `plugins/{plugin}/scripts/lib/`: bash files are sourced, jq modules load via `jq -L`, GraphQL fragments via `cat`. Skill scripts resolve the lib dir relative to their own physical path — `SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"` then `"${SCRIPT_DIR}/../../../scripts/lib"` — because other agents run them through a `~/.agents/skills/<skill>` symlink, where the logical `../../..` leaves the marketplace
3. Use bash shebang: `#!/usr/bin/env bash`
4. Set strict mode: `set -euo pipefail` (executable scripts only — sourced libs leave options to the caller)
5. Quote all variables: `"${var}"`
6. Use `readonly` for constants
7. Make executable: `chmod +x script.sh`
8. Python scripts follow the same spirit: `#!/usr/bin/env python3`, stdlib only (no package manifests), argparse CLI, `encoding="utf-8"` on every file read/write

### Modifying Base Plugin

The `base` plugin (`plugins/base/`) holds every workflow (skills, hooks, agents, output styles); MCP servers live in the `mcp` plugin below:

**User-driven skills** (`disable-model-invocation: true`, invoked via `/skill-name`):
- `creating-memo` - Timestamped memo with ULID in `~/projects/github.com/kkhys/me/apps/memo/memo-content/memo/`
- `publishing-pr` - Complete git workflow: branch creation → commit split → PR creation
- `creating-codepen-demo` - Create CodePen demos
- `creating-task-summary` - Create weekly task summaries
- `uploading-knowledge-gist` - Upload session knowledge to secret GitHub Gist
- `digging` - Interrogate a plan, design, or decision one question at a time until shared understanding is reached
- `creating-trend-digest` - Collect today's trends from 10 sources (HN, Hatena, Zenn, Qiita, Lobsters, Reddit, GitHub Trending, dev.to, Techmeme, Hugging Face Daily Papers), score by personal interest profile in `~/.claude/trend-digest/`, and publish the digest to trends.kkhys.me (JSON commit → deploy → push in the me repo)
- `explaining-like-doraemon` - Re-explain a hard answer from the current session as a のび太/ドラえもん dialogue, then restate it with the precise terms and file paths
- `creating-handoff` - Compact the current conversation into a handoff document in `~/.claude/handoffs/<YYYYMMDD-HHmm>-<slug>.md` (state, decisions, artifact links, suggested skills, secrets redacted) so a fresh session can continue the work

**Model-invocable skills** (discovered by Claude, also invocable via `/skill-name`):

Git workflow:
- `formatting-commit` - Conventional Commits format
- `splitting-commit` - Split commits by semantic meaning
- `creating-branch-name` - Create branch with appropriate naming
- `creating-pr` - GitHub PR creation
- `creating-stacked-pr` - Verify whether a task should be split into stacked PRs, design layers, build the stack with gh-stack
- `resolving-merge-conflicts` - Resolve in-progress merge/rebase conflicts by intent — trace each hunk to its commit/PR/issue, preserve both sides, run the project's checks, finish the merge or rebase. A conflicting PR into `develop` is landed by merging the head branch into local develop and pushing develop after confirmation; PRs into any other base resolve on the head branch

PR review:
- `reading-unresolved-pr-comments` - Fetch unresolved PR review comments and create fix plan
- `resolving-pr-comments` - Resolve review threads on the current PR (all unresolved, or a specific thread ID list)
- `fixing-review-comments` - Address unresolved review comments on the current branch
- `posting-pr-review` - Post review comments to a GitHub PR as a PENDING review
- `babysitting-pr` - Monitor a PR until it is mergeable (draft: until review comments are resolved): long-poll CI/review/merge state via `pr-watch.sh`, autonomously fix branch-caused CI failures and actionable review comments, and re-request Copilot review after each fix round until Copilot stops commenting

Other:
- `summarizing-release-notes` - Summarize recent Claude Code release notes
- `diagnosing-bugs` - Six-phase diagnosis loop for hard bugs and performance regressions: tight red-capable feedback loop first (HITL template in `scripts/`), then reproduce/minimise, ranked hypotheses, tagged instrumentation, fix behind a regression test, cleanup
- `writing-for-agents` - Levers for writing documents an agent consumes (skills, CLAUDE.md, references): context pointers, the two loads, information hierarchy, completion criteria, leading words, pruning; `references/skill-mechanics.md` covers invocation choice and router skills
- `writing-japanese-tech-docs` - Norms for Japanese technical prose (book chapters, articles, explainers), covering both drafting and revision. `SKILL.md` carries the always-applicable core (一文一行, 話題テスト, LLM 口調, 段落は論証の一歩, 未回収の緊張, 断定の境界) plus the agent dispatch and consolidation format; the full rule sets live in `references/argument.md`, `references/rhythm.md`, and `references/prose.md`. Adapted from k16shikano's gists — see `THIRD_PARTY_NOTICES.md`

**Agents** (`plugins/base/agents/`):
- `general-purpose-assistant` - Fallback agent for broad inquiries and cross-domain tasks

**Skill-owned agents** (`plugins/base/skills/writing-japanese-tech-docs/agents/`, registered through the manifest's `agents` array). Dispatched only by `writing-japanese-tech-docs`; each reads the skill's core section plus its own norm file, both passed as absolute paths in the dispatch prompt:
- `argument-auditor` - Paragraph order, logical gaps between paragraphs, argumentative rigour, honesty toward the reader (`references/argument.md`)
- `rhythm-designer` - Cognitive rhythm, sentence beat, unrecovered tension, self-narrating filler, reader load (`references/rhythm.md`)
- `prose-auditor` - Formatting and punctuation, headings, voice and terminology, restraint on rhetoric, redundancy (`references/prose.md`)
- `technical-accuracy-checker` - Technical claims, code samples, numbers, API references; carries its own verification procedure and has web access

**Output Styles** (`plugins/base/output-styles/`), selected from `/config` → Output style:
- `terse-japanese` - Terse Japanese replies: politeness, filler, and tool-call narration dropped; technical substance, negations, numbers, identifiers, and code blocks kept verbatim. Compresses the chat prose only — investigation depth, verification, and anything written to a file or GitHub stay normal

When modifying, maintain consistency with existing patterns and update version in `.claude-plugin/plugin.json`.

### Modifying MCP Plugin

The `mcp` plugin (`plugins/mcp/`) is a manifest plus `.mcp.json`, no skills. It exists so the same server list reaches every agent: Claude Code and Codex install it from the marketplace, Devin links the directory, Copilot installs it and runs `copilot plugin update`, and the dotfiles activation generates Gemini `mcpServers` (HTTP → `httpUrl`) and Cursor `~/.cursor/mcp.json` from the file.

**MCP Servers** (`plugins/mcp/.mcp.json`):
- `context7` - Library documentation lookup (HTTP, no API key)
- `serena` - Symbol-level code navigation and editing via `uvx`
- `playwright` - Browser automation via `@playwright/mcp`
- `chrome-devtools` - Chrome DevTools automation
- `astro-docs` - Astro documentation search (HTTP)
- `analytics-mcp` - Google Analytics queries. `GOOGLE_PROJECT_ID` is literal in the file; auth uses gcloud application default credentials (`gcloud auth application-default login`)

Adding or renaming a server changes its tool names (`mcp__plugin_mcp_<server>__*`), so update the permission entries in `dotfiles/.config/claude/settings.json` in the same change. Bump `plugins/mcp/.claude-plugin/plugin.json` on every edit — Claude Code's marketplace auto-update only picks up a new version.

## Important Patterns

### Skills as the Single Interface

Skills cover both auto-discovery by Claude and explicit `/skill-name` invocation — there is no separate command layer. Choose the invocation mode per skill:
- Model + user invocable (default): knowledge and conventions Claude should apply when relevant (e.g., `formatting-commit`)
- `disable-model-invocation: true`: side-effectful or user-timed workflows (e.g., `/creating-memo`, `/publishing-pr`)
- `user-invocable: false`: background knowledge that is not a meaningful user action

### Skills shared with other agents

Every `plugins/*/skills/<name>/` is symlinked to `~/.agents/skills/<name>` by the dotfiles nix activation, and Codex, Gemini CLI, Cursor, Devin and Copilot CLI read that directory. Claude Code does not read `~/.agents/skills`, so each skill is listed once per agent. The other readers are stricter and substitute less than Claude Code:

- `name` and `description` are mandatory — Gemini drops a skill that lacks either, silently. `name` must equal the directory name (Cursor requires it; Codex lists the skill as `base:<name>` from the canonical path)
- `SKILL.md` sits directly in `skills/<name>/` — Gemini only globs `SKILL.md` and `*/SKILL.md` under each root, so a deeper layout is invisible
- Nothing but Claude Code substitutes `${CLAUDE_SKILL_DIR}`, `$ARGUMENTS`, or runs `` !`cmd` `` injection. A skill that references its own files adds one line next to the first reference: "`${CLAUDE_SKILL_DIR}` is this skill's directory; when the variable reaches you unexpanded, use the directory that holds this SKILL.md." Treat `$ARGUMENTS` and `` !`cmd` `` output as possibly absent
- Scripts that reach `scripts/lib` resolve their own physical path (see "Adding New Scripts") — a logical `../../..` from the symlink leaves the marketplace
- `disable-model-invocation` is Claude-only; a side-effect skill's `description` must therefore already scope it to explicit requests, because other agents can pick it by description alone
- Only `SKILL.md` and the files it points at travel: the other readers look for `SKILL.md` alone, so skill-owned `agents/`, plugin `hooks/`, and `output-styles/` stay Claude Code features

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

- All executable bash scripts use `set -euo pipefail` for strict error handling; sourced libraries in `scripts/lib/` set no shell options
- No package.json - this is a pure plugin marketplace (no npm dependencies)
- MCP servers extend Claude Code capabilities without plugin code changes
- Skills are knowledge bundles, not executable code (use scripts for automation)
- Conventional Commits types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`
- PR title format: `[base-branch] type: description` (e.g., `[main] feat: add authentication`)
