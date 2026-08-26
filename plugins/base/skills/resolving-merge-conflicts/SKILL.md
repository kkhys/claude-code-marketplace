---
name: resolving-merge-conflicts
description: >-
  Resolve an in-progress git merge, rebase, or cherry-pick conflict by intent:
  trace each side to its primary source (commit, PR, issue), preserve both
  intents per hunk, run the project's own checks, and carry the operation to a
  finished commit. A PR into develop that GitHub reports as conflicting is
  landed by merging its head branch into local develop, resolving there, and
  pushing develop after the user confirms; PRs into any other base resolve on
  the head branch.
when_to_use: >-
  Use whenever the tree is mid-merge or mid-rebase with conflict markers —
  "コンフリクト解消して", "マージコンフリクト", "rebase が止まった",
  "resolve conflicts", "fix the merge", "CONFLICT (content)" in git output,
  or `git status` reporting unmerged paths. Also when a PR cannot be merged
  because of conflicts — "PR がコンフリクトしてマージできない", "This branch
  has conflicts that must be resolved" — and when a git command the agent
  itself ran (merge, rebase, pull, cherry-pick, gh stack sync) stopped on
  conflicts.
argument-hint: "[goal of this merge/rebase (optional)]"
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

Clean tree and a PR that GitHub reports as conflicting: the branch to resolve
on follows the PR's base (`gh pr view --json baseRefName,headRefName`).

- Base `develop`: resolve on develop itself. Bring local develop up to date,
  merge the head branch into it, and land the PR by pushing develop — GitHub
  marks the PR merged once its head commit is reachable from develop, so the
  merge button is never pressed. This is not a way around review: the result
  is the same merge the button would produce, and the confirmation asked for
  before the push stands in for pressing it. What it buys is a conflict
  resolved once, by hand and with the checks run, instead of left for whoever
  merges. The flow starts and ends on develop; main is left as it is.

  ```sh
  git checkout develop
  git pull --ff-only
  git merge --no-ff <head-branch>   # stops on conflicts → Process
  ```

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

3. Resolve each hunk. Preserve both intents where possible. Where
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
   - develop — show the merge commit (`git show --stat HEAD`) and the check
     results, and push only after an explicit yes: `git push origin develop`.
     This push is the merge, and it lands without GitHub re-running the PR's
     checks, so the confirmation stands in for the merge button.

## Report

Per hunk: what was kept, what was dropped, and why. Name the checks that ran.
When the operation produced a merge commit, the trade-offs go in its body;
otherwise they go in the report. On the develop path, name the pushed develop
commit.
