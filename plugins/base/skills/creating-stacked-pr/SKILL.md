---
name: creating-stacked-pr
description: >-
  Decide whether a development task should be a stack of dependent PRs —
  single PR is the default answer — design the layers at reviewable
  granularity, and build the stack with the gh-stack CLI under this
  project's conventions ("[main] type: description" titles, draft PRs,
  assignee kkhys).
when_to_use: >-
  Always consult when the user mentions stacked PRs, dependent PRs, or
  splitting work into multiple PRs — "stacked PR", "スタックPR", "PR分割",
  "PRを分けて", "段階的にレビューできるように", "gh stack". Also trigger
  before implementing any large task that spans multiple dependent concerns
  (schema + API + UI, refactor + feature built on it), or when an existing
  branch has grown too large to review as one PR and should be split.
  Includes deciding NOT to stack — consult even to verify that a task is
  fine as a single PR.
argument-hint: "[task description | split current branch]"
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Skill
---

# Creating Stacked PRs

## Task

$ARGUMENTS

If blank, evaluate the task or branch under discussion.

A stack is one large change split into a chain of dependent PRs, each
showing only its own layer's diff. The work always proceeds verify → design
→ build. The verify verdict is the point, and "single PR" is the default
answer — a stack the reviewer did not need costs more than it saves.

## Phase 1 — Verify: should this task be a stack?

Identify the concerns — a refactoring, a feature, a schema change — the same
unit `splitting-commit` uses at commit level.

Stack only when all of these hold:

- Two or more concerns, and later ones depend on earlier ones (schema before
  API, refactor before the feature that uses it)
- The combined diff is too large for one sitting — roughly 400+ changed
  lines, or mixed audiences (backend + frontend reviewers)
- Each layer is independently reviewable — a reviewer could approve the
  refactor without seeing the feature

Otherwise one PR: a single concern however many files it touches; concerns
that are independent of each other (separate PRs, not a stack); a small
total diff (two 60-line layers are overhead); layers with no semantic
boundary (splitting by file count is not splitting by concern).

State the verdict with its reasoning before touching git — "3 dependent
concerns, ~800 lines → stack of 3" or "single concern → normal PR" — and
hand a non-stack to the usual commit / PR flow.

## Phase 2 — Design the layers

- Dependency order: shared types, schema, utilities low; API, UI,
  integration high. Code in a layer uses only its own layer and lower ones.
- One concern per layer. Tests ship with the code they verify, and every
  layer compiles and passes with only the layers below it present, because
  CI runs per PR.
- 2–5 layers of roughly 100–400 changed lines. More than 6 usually means
  two features — two stacks. Semantic boundaries win over line counts.
- Branch names follow `creating-branch-name`, each layer with its own type,
  so a stack reads `refactor/extract-validation → feature/add-profiles →
  docs/document-profiles`.

Show the plan and wait for approval before creating anything:

```
Stack plan (bottom → top, base: main):
1. refactor/extract-validation — pull validation helpers out of handlers (~150 lines)
2. feature/add-profile-model   — Profile model + storage + tests (~200 lines)
3. feature/add-profile-api     — API endpoints using the model + tests (~250 lines)
```

## Phase 3 — Build

Every `gh stack` command comes from the `gh-stack` skill — invoke it before
the first one. It carries the non-interactive forms (`init <branch>`,
`add <branch>`, `submit --auto`, `view --json`), the exit codes, rebase
conflict recovery, and the recipes for splitting a branch that already
holds mixed commits. Without that skill, install the extension
(`gh extension install github/gh-stack`) and read `gh stack --help`.

Implement bottom-up: `gh stack init <branch-1>`, commit layer 1 with
`formatting-commit`, `gh stack add <branch-2>`, and so on. A change that
belongs to a lower layer is committed there (`gh stack checkout`, commit,
`gh stack rebase --upstack`), never left in a higher branch where it lands
in the wrong PR. Before splitting an existing branch, keep a safety ref:
`git branch backup/<name>`.

## Phase 4 — Submit and apply project conventions

`gh stack submit --auto` pushes every branch and opens draft PRs with
commit-derived titles. Immediately bring each PR in line with `creating-pr`
(title format, type, body, assignee) via `gh pr edit`:

```bash
gh pr edit <number> --title "[main] refactor: extract validation helpers" --add-assignee kkhys
```

Two stack-specific rules on top of `creating-pr`:

- Title brackets name the stack's base (`[main]`), not the PR's direct
  parent. GitHub evaluates every PR against the stack base and retargets
  on partial merge, so `[main]` stays correct for the stack's lifetime.
- Each PR's type and body cover its own layer only. The stack map already
  shows the whole; do not repeat it per body.

Finish by listing all PR URLs bottom → top, one line each.

## Fallback: stacked PRs unavailable

If `gh stack submit` exits 9 (feature not enabled for the repository) or the
extension cannot be installed, build a manual chain with the same layers:
push each branch and `gh pr create --base <branch below> --draft
--assignee kkhys` with `[main]` titles. Say what is lost — no stack map, no
atomic merge, and after each merge the next PR is retargeted to main by
hand unless the merged head branch is deleted. `gh stack link <b1> <b2> ...`
upgrades the chain in place once the feature is enabled.
