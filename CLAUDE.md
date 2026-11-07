# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin marketplace that provides custom skills and workflows. The marketplace enables installation of plugins containing skills (knowledge bundles, also invocable as `/skill-name`), hooks (event automation), and MCP server configurations. Custom slash commands have been merged into skills — this marketplace no longer uses `commands/` directories.

Claude Code is the only consumer. Nothing here is written for another agent: Claude Code's substitutions (`${CLAUDE_SKILL_DIR}`, `$ARGUMENTS`, `${user_config.KEY}`) are relied on without fallbacks.

## Architecture

### Marketplace Structure

```
.claude-plugin/
  marketplace.json          # Marketplace metadata and plugin registry
.github/workflows/
  validate.yml              # CI: manifest validation + shellcheck
plugins/
  base/                    # The one plugin
    .claude-plugin/
      plugin.json          # Plugin metadata, component paths
    skills/                # Skills (SKILL.md + references/ + scripts/ + agents/)
    hooks/                 # Event hooks (hooks.json)
    scripts/               # Shell scripts for automation
    .mcp.json              # MCP server configuration
```

Components that exist in the plugin spec but are unused here: `workflows/` (Workflow scripts), `output-styles/` (the chat register comes from Claude Code's built-in `Concise` style, selected through `outputStyle` in `settings.json`), `monitors/`, `themes/`, `.lsp.json`, and `dependencies`. Add them only when there is a concrete need.

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

**MCP Servers** (`.mcp.json`): External tool integrations
- HTTP servers: `type: "http"`, `url`
- Stdio/command servers: `command`, `args`
- Never hardcode machine-specific paths or secrets — declare them in `plugin.json` `userConfig` and reference as `${user_config.KEY}`
- Hooks and `settings.json` permissions address a bundled server by the scoped tool name `mcp__plugin_<plugin>_<server>__<tool>` — here `mcp__plugin_base_<server>__*`. Renaming a server renames its tools

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

# Validate the plugin manifest — the marketplace check does not cover it
claude plugin validate ./plugins/base --strict

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

# Delete and keep rules of the Stop hook's branch cleanup, in throwaway git repos
bash plugins/base/scripts/test-cleanup-merged-branches.sh

# Prompt selection, tokenizer, dictation pairing, window and ignore-list state, and apply failure modes for registering-hex-vocabulary
bash plugins/base/skills/registering-hex-vocabulary/scripts/test-hex-vocabulary.sh

# Caption bar and console panel API, console mirror, and navigation state of recording-pr-qa's init script, in a node vm
bash plugins/base/skills/recording-pr-qa/scripts/test-qa-overlay.sh

# Reference rewriting, the one-pending-review rule, and the checks before the first upload of recording-pr-qa's review placement, against a gh stub
bash plugins/base/skills/recording-pr-qa/scripts/test-place-qa-review.sh
```

CI (`.github/workflows/validate.yml`) runs manifest validation, ShellCheck, Python syntax checks, and the script tests on pull requests and pushes to `main`. Every `test-*.sh` under `plugins/*/scripts/` and `plugins/*/skills/*/scripts/` is picked up automatically — new test scripts need no CI change.

### Local Testing

```bash
# Add marketplace locally
/plugin marketplace add ./path/to/claude-code-marketplace

# Install plugin
/plugin install base@my-marketplace

# Test a user-invoked skill
/creating-handoff "continue the skill refactor"
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
6. If the skill is ported or adapted from another project, record the source, its license, and the derived paths in `THIRD_PARTY_NOTICES.md`

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
2. Helpers shared across skills live in `plugins/{plugin}/scripts/lib/`: bash files are sourced, jq modules load via `jq -L`, GraphQL fragments via `cat`. Skill scripts resolve the lib dir relative to their own path (`"${SCRIPT_DIR}/../../../scripts/lib"`)
3. Use bash shebang: `#!/usr/bin/env bash`
4. Set strict mode: `set -euo pipefail` (executable scripts only — sourced libs leave options to the caller)
5. Quote all variables: `"${var}"`
6. Use `readonly` for constants
7. Make executable: `chmod +x script.sh`
8. Python scripts follow the same spirit: `#!/usr/bin/env python3`, stdlib only (no package manifests), argparse CLI, `encoding="utf-8"` on every file read/write

### Modifying Base Plugin

The `base` plugin (`plugins/base/`) is the only plugin in this marketplace, and holds every workflow (skills, hooks, agents, MCP servers). The skill catalog is the directory itself: each `plugins/base/skills/*/SKILL.md` frontmatter carries the description and the invocation mode (`disable-model-invocation` marks the user-driven ones), so nothing is listed twice here. What the frontmatter does not say:

- `publishing-pr` orchestrates `creating-branch-name` → `splitting-commit` → `creating-pr`; `splitting-commit` calls `formatting-commit` per group
- `formatting-commit` sets the new-commit-not-amend rule for anything under review; `fixing-review-comments`, `diagnosing-ci-failure`, and `babysitting-pr` rely on it
- `fixing-review-comments` starts with `reading-unresolved-pr-comments` and ends by replying; `babysitting-pr` wraps that cycle and is the one caller allowed to run `resolving-pr-comments` without confirmation
- `reviewing-pr` delegates the review to `pr-review-toolkit:review-pr` and owns only the verdict block; `posting-pr-review` posts what the user vetted
- `diagnosing-ci-failure` reuses `babysitting-pr`'s `scripts/pr-watch.sh --failed-logs` and `references/ci-heuristics.md`, and `merging-renovate-prs` reuses `scripts/pr-watch.sh --pr` (`--once`, `--wait`, `--failed-logs`), all through `${CLAUDE_SKILL_DIR}/../babysitting-pr/` — keep those paths stable
- `merging-renovate-prs` merges only in repositories owned by `kkhys` and only PRs authored by `app/renovate`; the owner check is the first step and is not negotiable from the prompt. It hands CI failures to `diagnosing-ci-failure`
- `creating-stacked-pr` owns the stack-or-not verdict and the project conventions; command mechanics come from the external `gh-stack` skill, which the skills CLI installs into `~/.claude/skills`
- `reviewing-pr` reads past the diff (callers, tests, expected load) and keeps a finding only with a concrete case; those rules and the problem / fix / if-skipped shape of a 指摘 are ported from ponytail (see `THIRD_PARTY_NOTICES.md`)
- `illustrating-pr` is one file on purpose, in the eli15 register: the drawing is left to the model in a few lines, and the mechanics are two commands written in the skill — a local Chrome screenshot and `gh pr edit --attach` (gh ≥ 2.99). It keeps a `## In pictures` section at the end of the description and replaces it on rerun. No scripts, skeleton, palette, or tests: a wrapper there only fixed the canvas and file names the model should be free to choose
- `recording-pr-qa` runs the PR's manual test in headless Chrome through Playwright CLI (`playwright-cli` from mise's `npm:@playwright/cli`, or `npx --no-install playwright cli` in a project that depends on playwright; the session opens with `open --config`, whose `channel: chrome` uses the installed Google Chrome, so no browser download, whose `initScript` loads the overlay, and whose `outputDir` keeps the files `snapshot` writes out of the repository) and places the evidence plus the case list in the PR description with `gh pr edit --attach`: a case whose observable is a state (a colour, a text, a variant) is a `screenshot`, one whose observable is a transition is a chapter of one MP4. The layout follows the body: a template with `### Test Cases (Human-Verified)` and `## Screenshot(s)` (the work template) gets the cases as Human-Verified checkboxes — the user checks the evidence before asking for review — with the not-checked list folded in `<details>`, the evidence under `## Screenshot(s)`, the used environment ticked with the preview URL, and `### Test Cases (AI-Suggested)` left untouched as the source of the cases; any other body gets a `## Manual QA` section, replaced on rerun. Evidence is written as markdown references to the local files, which gh (≥ 2.99) rewrites to the uploaded assets in place; raw `<img>` is not rewritten, so a width comes from a second edit. A login is the user's own, done once in a headed session and kept with `state-save` under `$XDG_STATE_HOME/recording-pr-qa/`. `scripts/qa-overlay.js` is a context init script that zooms every page 2x (Playwright records at the CSS viewport size and never above it, so a 2560x1800 viewport with zoom 2 is how the 1280x900 layout is filmed at Retina density) and draws a caption bar and a console panel into every page — inert, aria-hidden, closed shadow root, so snapshots and the app never see it — draws a ripple on every mousedown, and exposes `window.__qa` (`step`, `check`, `log`, `place`, `hide`, `show`, `clear`); chapter cards, action callouts and the travelling cursor are Playwright's own `video-chapter` / `video-show-actions` / `video-start --cursor`. Playwright runs Chrome with bfcache off, so the config also carries `ignoreDefaultArgs: ["--disable-back-forward-cache"]` for `history.back()` cases. The environment is chosen in a fixed order (`--url`, a preview deployment of the head, production for a merged PR with analytics blocked and no writes, else a worktree build served locally), and the run is two-pass: rehearse without recording, then capture the rehearsed commands from one script in a single Bash call, so the time between tool calls never lands on film; targets are selectors, since refs are renumbered on every navigation. On a PR the user reviews (`--review`, or an author other than the viewer) the same `## Manual QA` section goes into the user's pending review through `scripts/place-qa-review.sh`: `gh pr review` has no `--attach`, so the script uploads the files to the repository's attachment store itself (`POST https://uploads.github.com/user-attachments/assets`, the endpoint behind `--attach`; push access required), rewrites the references, and updates the user's existing pending review — GitHub allows one per PR, and `posting-pr-review` may have made it — or creates one. Posting waits for the user unless `--post`
- `registering-hex-vocabulary` is built for `claude -p "/base:registering-hex-vocabulary"` on a schedule: `scripts/hex-vocabulary.py extract` reads only prompts with `promptSource` `typed` or `queued` (what the user actually typed or dictated; tool results, hooks, SDK turns, subagent transcripts, and Orca's hand-off brief are left out) for the names, and `hex history` for the dictations themselves, each paired with the prompt sent within thirty minutes after it when that prompt carries a hand-corrected version — the evidence for a mishearing a tokenizer cannot see (常規 for 上記). `apply` registers names through `hex vocabulary add` and mishearings as replacements in the Global mode (`hex settings set dictation_processing.default_mode`, one read-modify-write that appends), the one fix that acts on every transcript whatever the model or rewrite settings; it refuses a `from` shorter than two characters, absent from every dictation Hex retains, or present in more than a fifth of them, so the agent can only rewrite what the user actually said and never a word they say all the time. The window (`last_run`) and the terms Claude rejected live in `$XDG_STATE_HOME/registering-hex-vocabulary/state.json`, so rejected terms are never proposed twice; the window only advances when every write landed. People and credentials reach neither Hex nor that file: the script strips e-mail addresses, @mentions, tokens, and random strings before tokenizing or quoting a dictation and extracts no names before さん, and the skill gives a person or a secret no verdict at all. `hex` is resolved from PATH, else `/Applications/Hex.app/Contents/MacOS/hex` — the Homebrew cask does not link the CLI

**Hooks** (`plugins/base/hooks/hooks.json`): one `Stop` hook, `scripts/cleanup-merged-branches.sh`. It deletes local branches that are ancestors of `main` or `origin/main`, or whose upstream is `[gone]` — the only signal a squash merge leaves — when `gh` confirms the local tip headed a merged PR; a gone branch with later local commits is kept and reported. The `[gone]` half relies on `fetch.prune = true` in `dotfiles/.config/nix/home-manager/programs/git.nix`; the script never fetches. It runs synchronously (tens of milliseconds) and reports deletions through `systemMessage` — keep it that way, an async hook's output is never shown. Notification sounds are Orca's job, not a hook's.

**MCP Servers** (`plugins/base/.mcp.json`):
- `serena` - Symbol-level code navigation and editing via `uvx`, pinned to a Serena release tag: the server runs with the user's permissions, so the ref moves only on purpose, with a plugin version bump

The plugin ships only servers that every session needs. Documentation lookup and browser automation (context7, playwright, chrome-devtools) belong to the projects that use them — their own `.mcp.json` or the official plugins — so they are not declared here; a plugin-level copy would start them twice.

Adding or renaming a server changes its tool names (`mcp__plugin_base_<server>__*`), so update the permission entries in `dotfiles/.config/claude/settings.json` in the same change.

When modifying, maintain consistency with existing patterns and update version in `.claude-plugin/plugin.json` — Claude Code's marketplace auto-update only picks up a new version.

## Important Patterns

### Skills as the Single Interface

Skills cover both auto-discovery by Claude and explicit `/skill-name` invocation — there is no separate command layer. Choose the invocation mode per skill:
- Model + user invocable (default): knowledge and conventions Claude should apply when relevant (e.g., `formatting-commit`)
- `disable-model-invocation: true`: side-effectful or user-timed workflows (e.g., `/creating-handoff`, `/publishing-pr`)
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

Every comment posted to GitHub from this marketplace starts with `[from Claude Code]`, so reviewers can tell an agent's comment from the user's own. `reply-to-review-threads.sh` and `post-pr-review.sh` prepend it idempotently — write bodies without it. Add it by hand when posting with plain `gh pr comment`. The exceptions are `illustrating-pr`'s picture section and `recording-pr-qa`'s `## Manual QA` section, in the PR body or in the user's pending review: both are the user's own material — the author's on their PR, the reviewer's in the review they submit — vetted before placement, so they carry no marker.

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
