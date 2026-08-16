---
name: resolving-merge-conflicts
description: >-
  Resolve an in-progress git merge, rebase, or cherry-pick conflict by intent:
  trace each side to its primary source (commit, PR, issue), preserve both
  intents per hunk, run the project's own checks, and carry the operation to a
  finished commit.
when_to_use: >-
  Use whenever the tree is mid-merge or mid-rebase with conflict markers —
  "コンフリクト解消して", "マージコンフリクト", "rebase が止まった",
  "resolve conflicts", "fix the merge", "CONFLICT (content)" in git output,
  or `git status` reporting unmerged paths. Also when a git command the agent
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

## Report

Per hunk: what was kept, what was dropped, and why. Name the checks that ran.
When the operation produced a merge commit, the trade-offs go in its body;
otherwise they go in the report.
