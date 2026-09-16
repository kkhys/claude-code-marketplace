---
name: formatting-commit
description: Enforce Conventional Commits format for git commits, including project-specific scope conventions (plugin name as scope in this marketplace) and the new-commit-versus-amend decision — new commit by default, always under review.
when_to_use: >-
  Always consult when committing code changes — "commit", "コミット",
  "コミットして", "変更を記録", "save changes", "stage and commit", choosing
  between feat and fix, deciding between amend and new commit, or any
  request to record, amend, or finalize changes in git. These conventions
  differ from defaults and cannot be inferred without this skill.
allowed-tools:
  - Bash(git:*)
  - Read
---

# Formatting Commit

## Current State

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -10`

## New commit or amend

New commit by default. Amend only when all of these hold: the previous
commit is not pushed, the change is a fixup of that commit (typo, forgotten
file), and a separate commit would be noise.

Under review the answer is always a new commit — one per fix round, scoped
to what that round changed — and a plain push. Amending a pushed commit
force-pushes, which detaches existing review comments from their lines and
erases the per-round diff the reviewer uses to check that their feedback
landed.

Reorganising several existing commits is `splitting-commit`'s job, not a
manual rebase here.

## Message

```
<type>(<scope>): <description>
```

Type by dominant intent, one of `feat` `fix` `refactor` `perf` `test`
`docs` `style` `build` `ci` `chore`. A feature with its tests is `feat`; a
bug fix with incidental refactoring is `fix`.

Scope is the area of the codebase. In this marketplace it is the plugin name
(`feat(base): …`, `chore(mcp): …`); omit it only for cross-cutting root
changes. Other repositories keep their own scope convention — read the
recent log.

Subject: imperative, lowercase, no trailing period, under 50 characters. A
body, when the change is non-trivial, says why — the subject already says
what. `!` after the type marks a breaking change.

## Process

1. Review the injected state; `git log --oneline origin/main..HEAD` shows
   branch-only commits when you need them
2. Stage specific files — be deliberate about what goes in
3. Commit, then verify with `git log -1 --stat`
