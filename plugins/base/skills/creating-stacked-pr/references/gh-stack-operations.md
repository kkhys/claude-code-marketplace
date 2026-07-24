# gh-stack operations for non-interactive use

The `gh stack` CLI defaults to interactive prompts and TUIs, which hang
forever in an agent context. Every invocation must carry the flags and
arguments that keep it non-interactive.

## Setup

```bash
gh extension list | grep -q 'gh stack' || gh extension install github/gh-stack
git config rerere.enabled true        # skip the rerere confirmation on init
git config remote.pushDefault origin  # skip the remote picker when multiple remotes exist
```

## Non-negotiable rules

| Command | Rule | Why |
|---|---|---|
| `gh stack init` | Always pass branch names: `gh stack init branch-a` | No args → interactive prompt |
| `gh stack add` | Always pass a branch name | No args → interactive prompt |
| `gh stack submit` | Always pass `--auto` | Without it, prompts for each PR title |
| `gh stack view` | Always pass `--json` | Without it, launches a TUI |
| `gh stack checkout` | Always pass a PR number or branch name | No args → interactive picker |
| `gh stack modify` | Never use | TUI only — restructure with `unstack` + `init` instead |

Branch names are used verbatim — `gh stack add refactor/foo` creates
`refactor/foo`, nothing is prefixed. Slashes are fine.

## Command quick reference

```bash
gh stack init <branch>              # create stack + first branch from trunk, check it out
gh stack init --base develop <b>    # non-default trunk
gh stack init <b1> <b2> <b3>        # adopt existing branches (must be linear ancestors)
gh stack add <branch>               # new branch on top (must be on the topmost branch)
gh stack view --json                # stack state as JSON (only safe form)
gh stack up / down / top / bottom   # navigate (skips merged branches)
gh stack checkout <branch|pr>       # switch stacks / pull a stack from a PR number
gh stack rebase                     # fetch + cascade-rebase the whole stack
gh stack rebase --upstack           # rebase only current branch → top (after mid-stack commit)
gh stack push                       # push all branches (--force-with-lease --atomic), no PRs
gh stack submit --auto              # push + create/update draft PRs + link stack on GitHub
gh stack sync                       # fetch, rebase, push, sync PR state (routine sync)
gh stack sync --prune               # …and delete local branches for merged PRs
gh stack unstack                    # dissolve the stack (branches and PRs survive)
gh stack link <b1> <b2> ...         # create/extend a stack on GitHub from branches/PR numbers
```

`submit` never sets custom titles or bodies — apply project conventions
afterward with `gh pr edit` (see SKILL.md Phase 4).

## Parsing `gh stack view --json`

Data goes to stdout, status messages to stderr.

```bash
out=$(gh stack view --json)
echo "$out" | jq -r '.currentBranch'
echo "$out" | jq -r '.branches[].name'                                   # bottom → top
echo "$out" | jq '[.branches[] | select(.needsRebase)] | length'         # >0 → run rebase
echo "$out" | jq -r '.branches[] | select(.pr.state == "OPEN") | .pr.url'
```

## Exit codes that matter

| Code | Meaning | Action |
|---|---|---|
| 0 | Success | Proceed |
| 2 | Not in a stack | `gh stack init` first |
| 3 | Rebase conflict | Resolve (below), `gh stack rebase --continue` |
| 5 | Invalid invocation | e.g. `add` while not on the topmost branch → `gh stack top` first |
| 6 | Branch in multiple stacks | Check out a non-shared branch first |
| 7 | Rebase in progress | `--continue` or `--abort` |
| 9 | Stacked PRs not enabled | Use the fallback chain in SKILL.md |

## Rebase conflicts

```bash
gh stack rebase                     # exit 3 → conflict
# parse stderr for conflicted paths, edit files to resolve <<<<<<< markers
git add <resolved-files>
gh stack rebase --continue          # repeat if it conflicts again
gh stack rebase --abort             # last resort: restores all branches
```

`init` enables `git rerere`, so a conflict resolved once is auto-resolved
in later cascades.

## Mid-stack changes

When a change belongs to a lower layer than the one checked out:

```bash
gh stack checkout <lower-branch>    # or: gh stack down
git add <files> && git commit ...   # commit where the change belongs
gh stack rebase --upstack           # cascade into the branches above
gh stack top                        # return to work
```

## Post-hoc split recipes

Always create a safety ref first: `git branch backup/<branch>`.

### Commits already align with layers

Commit history on `big-feature` (bottom-up): A B | C D | E, where `|`
marks layer boundaries.

```bash
git branch layer-1 <sha-of-B>
git branch layer-2 <sha-of-D>
git branch layer-3 big-feature          # or rename big-feature itself
gh stack init layer-1 layer-2 layer-3   # adopts existing linear branches
gh stack submit --auto
```

Use real `<type>/<description>` names, not `layer-N`.

### Commits are mixed across concerns

Flatten and rebuild:

```bash
git reset --soft $(git merge-base HEAD main)   # all changes staged, no commits
git switch main
gh stack init <branch-1>                        # working tree carries over
git restore --staged . && git add <layer-1 files> && git commit ...
gh stack add <branch-2>
git add <layer-2 files> && git commit ...
# ... repeat per layer; verify nothing is left: git status --short
```

If a single file mixes two layers' changes, put it in the layer where the
dominant change lives (same rule as `splitting-commit`) — per-hunk surgery
is rarely worth it.

### Uncommitted changes only

Skip the reset; start directly from `gh stack init` and stage per layer.

## Verifying the result

```bash
gh stack view --json                          # every branch present, needsRebase all false
git log --oneline --graph <trunk>..<top>      # linear, commits grouped by layer
git diff <lower>..<upper> --stat              # per-layer diff contains only that concern
```

Linear history is a hard requirement for stacked PRs — if `needsRebase`
is true anywhere, run `gh stack rebase` before submitting.
