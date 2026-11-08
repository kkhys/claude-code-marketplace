---
name: resolving-merge-conflicts
description: >-
  Resolve an in-progress git merge, rebase, or cherry-pick conflict by intent:
  trace each side to its primary source (commit, PR, issue), preserve both
  intents per hunk, run the project's own checks, and carry the operation to a
  finished commit. A PR into develop that GitHub reports as conflicting is
  resolved on a branch cut from origin/develop and landed on develop after the
  user confirms, so develop never flows into a main-bound branch; PRs into any
  other base resolve on the head branch.
when_to_use: >-
  Use whenever the tree is mid-merge or mid-rebase with conflict markers —
  "コンフリクト解消して", "マージコンフリクト", "rebase が止まった",
  "resolve conflicts", "fix the merge", "CONFLICT (content)" in git output,
  or `git status` reporting unmerged paths. Also when a PR cannot be merged
  because of conflicts — "PR がコンフリクトしてマージできない", "This branch
  has conflicts that must be resolved" — and when a git command the agent
  itself ran (merge, rebase, pull, cherry-pick, gh stack sync) stopped on
  conflicts. Also when develop was merged into a main-bound branch —
  "Update branch を押してしまった", "develop が混ざった".
argument-hint: "[PR URL(s) or the goal of this merge/rebase (optional)]"
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Read
  - Edit
  - Grep
  - Glob
---

# Resolving Merge Conflicts

A conflict is two changes made on purpose. Resolve it by intent, not by text:
`--ours` / `--theirs` only after reading both sides, and only when a whole
file's intent is one side's.

## Merge goal

$ARGUMENTS

If blank, infer the goal from the branch names and the commit being applied,
and state the inference before resolving anything.

## Current state

- Status: !`git status 2>/dev/null | head -5`
- Unmerged paths: !`git diff --name-only --diff-filter=U 2>/dev/null`
- PR: !`gh pr view --json baseRefName,headRefName,mergeStateStatus 2>/dev/null`

## Starting point

Already mid-merge or mid-rebase (unmerged paths above): go straight to
Process.

Clean tree and a PR that GitHub reports as conflicting — named by URL or
number, or several at once (「一連の stacked pr」 walks the stack from the
bottom; 「<prefix> で始まる PR 全て」 is `gh pr list --state open --search
'<prefix> in:title' --json number,headRefName,baseRefName,mergeable`), one
PR at a time: fetch its head branch first. When the user is working on
another branch in this checkout, or another worktree has the branch to
resolve on, neither switch branches nor add a worktree — worktrees are
opened in Orca: name that branch, and the path from `git worktree list` if
another worktree has it, and stop.

The branch to resolve on follows the PR's base
(`gh pr view --json baseRefName,headRefName`).

- Base `develop`: develop is a one-way sink — its commits must never reach
  main. The head branch of a develop PR is usually main-bound: `main` itself
  in a main -> develop sync PR, or a feature branch whose PR chain ends at
  main (`gh pr list --head <head-branch> --state all`). So the merge runs one
  way only: head into a branch cut from origin/develop, never develop into
  the head. Cut from origin/develop, not local develop, which is often stale
  and diverged:

  ```sh
  git fetch origin
  git switch -c merge/<head-branch>-into-develop origin/develop
  git merge --no-ff origin/<head-branch>   # stops on conflicts → Process
  ```

  GitHub marks the original PR merged once its head commit is reachable from
  develop, so the merge button on it is never pressed. The confirmation asked
  for before landing (step 6) stands in for pressing it. What this buys is a
  conflict resolved once, by hand and with the checks run, instead of left
  for whoever merges.

- Any other base (`main`, `master`, a stack parent): resolve on the head
  branch — merge the base into it, or rebase onto it, whichever the repo's
  history shows — then push the head branch and let the PR merge through
  GitHub.

## Process

1. See the current state of the merge/rebase. Check git history, and the
   conflicting files. `git log --oneline --left-right HEAD...MERGE_HEAD --
   <file>` shows what each side did to a file during a merge; `git log -1
   REBASE_HEAD` names the commit being replayed during a rebase.

2. Find the primary sources for each conflict. Understand deeply why each
   change was made, and what the original intent was. Read the commit
   messages (`git log -p`), check the PRs (`gh pr list --search <sha>`, `gh pr
   view`), check original issues/tickets.

3. Resolve each hunk. A file git reports as `Resolved ... using previous
   resolution` (rerere) still shows `UU`: read the replayed result against
   both sides like any other hunk, then `git add` it. Preserve both intents
   where possible. Where
   incompatible, pick the one matching the merge's stated goal and note the
   trade-off. Do not invent new behaviour.

   Carry the operation to a finished commit. When a hunk cannot be resolved
   from the two intents — they contradict and the merge's goal does not pick a
   side — stop, show both hunks with their sources, and ask the user which
   intent wins. Whether the merge should happen at all is the user's call to
   make before invoking; aborting is never the skill's move.

4. Discover the project's automated checks and run them — typically
   typecheck, then tests, then format. Look in `package.json` scripts, the
   Makefile, or the CI workflow. Fix anything the merge broke.

5. Finish the merge/rebase. Stage everything and commit. The Bash tool cannot
   drive an editor, so keep it non-interactive:
   - merge → `git commit --no-edit`
   - rebase → `GIT_EDITOR=true git rebase --continue`, then repeat steps 1–4
     for every further stop until `git status` is clean
   - cherry-pick → `git cherry-pick --continue`

6. Push the branch the resolution landed on, when it has an upstream to push
   to — a merge that never left this machine has nothing to land. Which push
   needs the user's word depends on what that push does:
   - Head branch (any base but develop) — `git push origin <head-branch>`.
     The PR still merges through GitHub afterwards, so this only updates what
     reviewers see. Push it as part of finishing the job, no confirmation
     needed.
   - develop — show the merge commit (`git show --stat HEAD`, both parents
     named) and the check results, and land it only after an explicit yes.
     Read the rules first: `gh api repos/{owner}/{repo}/rules/branches/develop`.
     With no `pull_request` rule, `git push origin HEAD:develop` is the merge
     itself. With one, push the merge branch and open a PR into develop that
     links the original PR; merging it marks the original merged too.

## develop leaked into a main-bound branch

GitHub's "Update branch" and web "Resolve conflicts" on a develop PR merge
develop into the head branch. Check with `git merge-base --is-ancestor
origin/develop origin/<branch>`; when it holds for a main-bound branch, reset
the branch to the commit before that merge, with the user's yes:

```sh
git push --force-with-lease=<branch>:<merge-sha> origin <pre-merge-sha>:refs/heads/<branch>
```

Reset, not revert: a revert keeps develop's commits as ancestors, so once the
branch reaches main, git treats those develop features as already merged and
drops them when their own PRs land. When the force push is denied by the
permission layer, hand the user the exact command to run with `!`. Afterwards
verify that main and every open PR head not based on develop contain none of
`git rev-list origin/develop --not origin/main`.

## Report

Per hunk: what was kept, what was dropped, and why. Name the checks that ran.
When the operation produced a merge commit, the trade-offs go in its body;
otherwise they go in the report. On the develop path, name the landed commit
or PR, and warn that "Update branch" and web "Resolve conflicts" on the
original PR would carry develop into main.
