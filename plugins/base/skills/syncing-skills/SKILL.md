---
name: syncing-skills
description: Sync this marketplace's skills to the portable skills repository, authoring the portable variant of Claude Code specific sections and running the deterministic converter.
when_to_use: >-
  Use when skills need to be propagated to the portable skills repository —
  "skills を同期", "sync skills", "ポータブル版を作って", after adding or
  editing a skill that also ships to Codex and Gemini CLI, or when CI reports
  that the skills repository is out of date.
argument-hint: "[skill-name | --check]"
allowed-tools:
  - Bash(bash:*)
  - Bash(git:*)
  - Read
  - Edit
disable-model-invocation: true
---

# Syncing Skills

Skills live in two places on purpose. This marketplace is the source of truth
and may use Claude Code features freely; the skills repository holds a portable
variant for Codex, Gemini CLI, and Copilot.

Duplication is safe because the search paths never overlap: Claude Code reads
plugins and `~/.claude/skills`, the other agents read `~/.agents/skills`. Never
link the skills repository into `~/.claude/skills` — that is the one change that
would make the same skill load twice.

## Division of Labor

The converter handles everything mechanical. This skill only handles the part
that needs judgment: writing the portable prose for a section that relies on a
Claude Code feature.

| Concern | Owner |
|---------|-------|
| Selecting annotated blocks, stripping frontmatter keys, copying assets | `scripts/sync-skills.sh` |
| Rejecting unportable constructs | `scripts/sync-skills.sh` |
| Detecting drift in CI | `scripts/sync-skills.sh --check` |
| Writing the portable variant of a section | This skill |
| Classifying a new skill | This skill |

## Annotation Format

Wrap each Claude Code specific section with a paired alternative. The converter
keeps the `portable:` block and drops the `claude:` block.

```markdown
<!-- claude:start -->
- Status: !`git status --short`
<!-- claude:end -->
<!-- portable:start -->
Run `git status --short` and read the output.
<!-- portable:end -->
```

Markers must sit on their own line. Anything outside a marker pair is shared by
both variants, so prefer neutral wording over annotating — "review the current
state above" reads correctly whether the state was injected or gathered.

Constructs that require annotation:

| Construct | Portable replacement |
|-----------|---------------------|
| `` !`cmd` `` | An instruction to run the command first |
| `$ARGUMENTS`, `$1` | An instruction to read the request for the value |
| `${CLAUDE_PLUGIN_ROOT}` | No equivalent — the skill stays Claude Code only |

`${CLAUDE_SKILL_DIR}` needs no annotation; the converter rewrites it to
`<SKILL_DIR>` and appends a definition line.

Frontmatter needs no annotation either. `context`, `agent`, `hooks`, `model`,
`effort`, `disable-model-invocation`, and `user-invocable` are stripped
automatically, so a skill using `context: fork` is still exportable — forking is
how Claude Code runs it, not what the skill does.

## Workflow

1. Run the converter in check mode against the skills repository:

   ```bash
   bash "<SKILL_DIR>/scripts/sync-skills.sh" --out ~/projects/github.com/kkhys/skills --check
   ```

2. If it reports unclassified skills, add each to `portable-skills.txt` as
   exported, `?pending`, or `!claude-only`. Ask the user when the call is not
   obvious from the skill's content.
3. If validation fails, open the named skill and add the missing annotation.
   Write the portable variant so it stands alone — a reader without the injected
   context must still know what to do.
4. Promote any `?pending` entry the user asks for by annotating the skill and
   removing the `?`.
5. Run without `--check` to write, then review the diff in the skills
   repository before committing.
6. If a skill was added or removed, update the task table in the skills
   repository's `AGENTS.md`. That table is what makes agents actually reach for
   a skill — a skill present but unlisted is frequently ignored.

## Commit Convention

The skills repository holds generated files. Commit them with
`chore(skills): sync from marketplace` and never edit them directly — the next
sync overwrites the change. Fix the source skill in this marketplace instead.
