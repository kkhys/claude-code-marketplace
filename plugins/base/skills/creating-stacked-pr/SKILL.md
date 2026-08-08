---
name: creating-stacked-pr
description: >-
  Evaluate whether a development task should be split into stacked PRs, design
  the layer structure at reviewable granularity, and build the stack with the
  gh-stack CLI following project conventions ("[main] type: description"
  titles, draft PRs, assignee kkhys).
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

If blank, evaluate the task or branch under discussion in the conversation.

A stacked PR splits one large change into a chain of small, dependent PRs.
Each branch builds on the one below it; each PR shows only its own layer's
diff, so reviewers evaluate one concern at a time while CI validates every
layer against the trunk.

```
main (trunk)
 └── refactor/extract-validation   → PR #1 (base: main)
  └── feature/add-profile-model    → PR #2 (base: refactor/extract-validation)
   └── feature/add-profile-api     → PR #3 (base: feature/add-profile-model)
```

The work always proceeds in three phases: verify → design → build. Never
skip the verify phase — the decision not to stack is as valuable as a good
stack.

## Phase 1 — Verify: should this task be a stack?

Analyze the task (or the existing diff) and identify its concerns. A
concern is a unit of intent — a refactoring, a feature, a schema change, a
migration — the same definition `splitting-commit` uses at commit level.

Stack when all of these hold:

- Two or more distinct concerns exist, and later ones depend on earlier
  ones (schema before API, refactor before feature that uses it)
- The combined diff would be too large to review in one sitting (roughly
  400+ changed lines, or mixed audiences: backend + frontend reviewers)
- Each concern is independently valuable to review — a reviewer could
  approve the refactor without seeing the feature

Do not stack when:

- The task is a single concern, however many files it touches — a rename
  across 20 files is still one PR
- Concerns are independent of each other — those are separate PRs (or
  separate stacks), not one stack; a stack must tell one story
- The total diff is small enough to review comfortably as one PR — a
  2-layer stack of 60 lines each is overhead, not kindness
- The layers would only exist to make PRs smaller, with no semantic
  boundary between them — splitting by file count is not splitting by
  concern

State the verdict explicitly with reasoning before doing anything:
"3 dependent concerns, ~800 lines expected → stack of 3" or "single
concern → normal PR" (then hand off to the usual commit/PR flow).

## Phase 2 — Design the layers

### Ordering and granularity

- Dependency order: foundations low, consumers high. Shared types, schema,
  and utilities go in lower branches; API, UI, and integration go higher.
  If code in one layer uses code from another, the dependency must live in
  the same layer or a lower one.
- One concern per layer. The test: could a reviewer approve this layer
  without reading the ones above it?
- Every layer must be green on its own. GitHub evaluates each PR in a
  stack as if it targets the trunk — CI runs per PR. Each layer must
  compile and pass tests with only the layers below it present. Tests ship
  in the same layer as the code they verify.
- 2–5 layers is the useful range, each ideally 100–400 changed lines.
  More than 6 layers usually means the task is really two features —
  consider separate stacks. Semantic boundaries always win over line
  counts: never split mid-concern to hit a size target.
- Layer boundaries follow the same patterns as `splitting-commit`:
  refactor before the feature built on it, rename/move separate from logic
  changes, fix before the feature that exposed the bug.

### Branch names and PR types

Name each branch with the `creating-branch-name` convention (that skill
defines the `<type>/<description>` format, the full-word type list, and
the kebab-case description rules). The stack-specific rule: each layer
gets its own type — a stack often reads
`refactor/extract-validation → feature/add-profiles → docs/document-profiles`,
which is exactly the story the reviewer should see.

### Present the plan and get approval

Before touching git, show the plan and wait for the user's approval:

```
Stack plan (bottom → top, base: main):
1. refactor/extract-validation — pull validation helpers out of handlers (~150 lines)
2. feature/add-profile-model   — Profile model + storage + tests (~200 lines)
3. feature/add-profile-api     — API endpoints using the model + tests (~250 lines)
```

Include what goes in each layer, the expected size, and why the boundary
is where it is. Adjust on feedback; only then start building.

## Phase 3 — Build the stack

Command mechanics, non-interactive flags, exit codes, and conflict
recovery live in [references/gh-stack-operations.md](references/gh-stack-operations.md)
— read it before running any `gh stack` command.

### Workflow A — plan-first (task not yet implemented)

Implement layer by layer, bottom up:

```bash
gh stack init refactor/extract-validation   # branch 1 from trunk
# ... implement layer 1 only ...
git add <layer-1 files>                      # commit via formatting-commit
gh stack add feature/add-profile-model      # branch 2 on top
# ... implement layer 2 ...
```

Multiple commits per branch are fine — use `splitting-commit` judgment
within a layer. If, while working on a higher layer, a change belongs to a
lower one: navigate down (`gh stack down` / `gh stack checkout <branch>`),
commit it there, run `gh stack rebase --upstack`, and come back up. Never
let a lower layer's change leak into a higher branch — it lands in the
wrong PR.

### Workflow B — post-hoc split (changes already exist on one branch)

Re-run Phase 1 and 2 against the actual diff (`git diff <trunk>...HEAD`),
then restructure. Create a backup ref first (`git branch backup/<name>`).
Three cases, detailed in the reference file:

- Commits already align with layer boundaries → create branches at the
  boundary commits and adopt them with `gh stack init`
- Commits are mixed → `git reset --soft $(git merge-base HEAD <trunk>)`,
  then rebuild as in Workflow A, staging each layer's files from the
  working tree
- Changes are uncommitted → directly rebuild as in Workflow A

## Phase 4 — Submit and apply project conventions

```bash
gh stack submit --auto        # pushes all branches, creates draft PRs, links the stack
```

`submit --auto` generates titles from commits and always creates drafts —
which matches this project's draft-first convention. Immediately after,
bring every PR in line with `creating-pr` conventions (title format, type
selection, body style, assignee — that skill is the single source for
them) via `gh pr edit`:

```bash
gh pr edit <number> --title "[main] refactor: extract validation helpers" --add-assignee kkhys
```

Two stack-specific rules on top of `creating-pr`:

- Title brackets name the stack's base branch (`[main]`), not the PR's
  direct parent. GitHub evaluates every PR in a stack against the stack
  base, and partial merges retarget PRs to it, so `[main]` stays correct
  for the stack's lifetime.
- Each PR's type and body cover its own layer only (the refactor layer is
  `refactor`, even if the stack exists for a `feat`). The stack map
  already shows the big picture — don't repeat it in each body.

Finish by listing all PR URLs bottom → top with one line each, so the
user can walk the stack in review order.

## Fallback: stacked PRs unavailable

Stacked PRs is in private preview. If `gh stack submit` exits with code 9
(feature not enabled for the repo), or the `gh-stack` extension is missing
and cannot be installed, fall back to a manual chain — same layer design,
plain PRs:

```bash
git push -u origin <branch>   # each branch
gh pr create --base main --title "[main] refactor: ..." --draft --assignee kkhys ...
gh pr create --base refactor/extract-validation --title "[main] feat: ..." --draft --assignee kkhys ...
```

Each PR's base is the branch below it, so per-PR diffs stay clean. Tell
the user what is lost: no stack map, no atomic bottom-up merge, and after
each merge the next PR must be retargeted to main manually (GitHub does
retarget automatically when the head branch of a merged PR is deleted).
If the feature is enabled later, `gh stack link <branch1> <branch2> ...`
upgrades the chain to a real stack in place.
