---
name: merging-renovate-prs
description: >-
  Merge the open Renovate pull requests of a repository owned by kkhys, one at
  a time — squash on green CI, wait for Renovate's own rebase when a PR falls
  behind, diagnose and fix a check the bump broke, and report what stays
  blocked. Refuses any repository whose owner is not kkhys and never touches a
  PR Renovate did not open.
when_to_use: >-
  Use when the user wants a repository's dependency PRs landed — "〜/pulls を
  全てマージして", "renovate の PR をマージして", "CI が pass していればマージ
  して、failed なら修正して", "merge the renovate PRs". Not for a single
  human-authored PR (babysitting-pr) or one failed run (diagnosing-ci-failure).
argument-hint: "[repository URL or owner/name (default: current directory)]"
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Read
  - Edit
  - Grep
  - Glob
  - Skill
---

# Merging Renovate PRs

## Target

$ARGUMENTS

If blank, the repository of the current directory.

## Guard

Before listing anything:

```bash
gh repo view [<repository>] --json owner,nameWithOwner --jq '"\(.owner.login) \(.nameWithOwner)"'
```

The owner must be exactly `kkhys`. Any other owner — a company organization,
a fork under another account — ends the skill right here: say which
repository it is and that this skill only merges in the user's personal
repositories. No merge happens outside them, whatever the user's wording.

Scope inside the repository: PRs whose author is `app/renovate`. Human PRs,
submodule PRs, and stacks are left untouched and named as skipped in the
report.

## Snapshot

```bash
gh pr list --repo <owner/name> --state open --limit 100 \
  --json number,title,headRefName,author,isDraft,mergeable,mergeStateStatus,url \
  --jq '[.[] | select(.author.login == "app/renovate")]'
```

Per PR, the babysitting-pr watcher gives CI and merge state in one snapshot.
`${CLAUDE_SKILL_DIR}` is this skill's directory; when the variable reaches
you unexpanded, use the directory that holds this SKILL.md:

```bash
bash "${CLAUDE_SKILL_DIR}/../babysitting-pr/scripts/pr-watch.sh" --pr <url> --once
bash "${CLAUDE_SKILL_DIR}/../babysitting-pr/scripts/pr-watch.sh" --pr <url> --wait   # Bash timeout 450000
bash "${CLAUDE_SKILL_DIR}/../babysitting-pr/scripts/pr-watch.sh" --pr <url> --failed-logs
```

Read `ci.is_green`, `ci.failed_checks`, `ci.pending_checks`, `pr.mergeable`,
`pr.merge_state_status`, `pr.head_sha`. Ignore `terminal`, `blockers`, and
`actions` — they encode babysitting's goals, not this loop's.

These repositories automerge minor and patch bumps through `renovate.json`,
so what is still open is usually a major bump (automerge off) or a PR whose
checks failed. Expect majors to merge on green and failures to need a
diagnosis.

## Loop

Lowest PR number first, one PR per iteration, fresh snapshot before each
decision:

1. Merged or closed since the list → count it and move on.
2. `merge_state_status` `BEHIND` or `DIRTY`, or `mergeable` `CONFLICTING` →
   Renovate rebases its own branches ("Rebasing: whenever PR is behind base
   branch, or you tick the rebase/retry checkbox"). Wait one `--wait` cycle;
   if the head SHA has not moved, tick the checkbox — replace
   `- [ ] <!-- rebase-check -->` with `- [x] <!-- rebase-check -->` in the
   body via `gh pr edit <n> --body-file` — and wait again. Never merge the
   base into a Renovate branch or resolve its lockfile by hand: Renovate
   regenerates both, and a hand-merged lockfile is the "矛盾" the user asked
   to avoid.
3. Checks pending → `--wait`.
4. Checks failed → `--failed-logs`, then invoke `diagnosing-ci-failure` with
   the PR URL. A failure the bump caused (type errors, a changed API, a
   lockfile the bump left stale) is fixed as a new commit on the Renovate
   branch; Renovate stops rebasing an edited branch, which is fine because
   the PR merges next. A flaky failure is rerun. A major that needs real
   migration work, or a failure outside the bump's scope, is reported with
   the log excerpt and left open for the user.
5. Green and `mergeable` `MERGEABLE` with `merge_state_status` `CLEAN` or
   `UNSTABLE` → merge, tied to the SHA whose checks you saw:

   ```bash
   gh pr merge <n> --repo <owner/name> --squash --match-head-commit <pr.head_sha>
   ```

   `gh pr merge` is on the settings ask list, so each merge prompts once;
   that is expected. After a merge that touched the lockfile, the remaining
   PRs flip to `BEHIND` and step 2 handles them.
6. Stop when no open Renovate PR remains or every remaining one is waiting
   on the user.

## Never

- `--admin`, `--auto`, `--merge`, or `--rebase`. Squash keeps one commit per
  bump, and the PR title is already the Conventional Commits message.
- Close a PR, edit `renovate.json`, or add an `allowedVersions` pin to make a
  failure disappear. Which bumps to refuse is the user's decision.
- Act on a PR Renovate did not open.

## Report

One line per PR: number, title, outcome — merged at `<sha>`, fixed and
merged, rebase requested and waiting, or blocked with the reason. Then the
PRs that were skipped as out of scope, and what the user has to decide.
