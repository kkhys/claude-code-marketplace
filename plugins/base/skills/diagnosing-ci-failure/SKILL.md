---
name: diagnosing-ci-failure
description: >-
  Diagnose one failed CI run or a PR's failing checks from a URL: pull the
  failed job logs, name the cause with the log excerpt, classify it as
  branch-caused or flaky, then fix it on the PR branch as a new commit or
  rerun the failed jobs.
when_to_use: >-
  Use when the user pastes a GitHub Actions run URL or a PR URL with "この
  CI の failed の原因は？", "ci が failed なので調査して修正して", "この
  エラーは何？", "why did CI fail", "fix CI". One diagnosis, not a watch
  loop — "green になるまで見てて" is babysitting-pr.
argument-hint: "[actions run URL | PR URL or number]"
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Read
  - Edit
  - Grep
  - Glob
---

# Diagnosing a CI Failure

## Target

$ARGUMENTS

## Get the logs

Never classify from a check name; read the failed job's log first.

From a run URL (`.../actions/runs/<run-id>[/job/<job-id>]`):

```bash
gh run view <run-id> --json headBranch,jobs \
  --jq '.jobs[] | select(.conclusion == "failure") | "\(.databaseId) \(.name)"'
gh api "repos/{owner}/{repo}/actions/jobs/<job-id>/logs" | tail -n 120
```

From a PR, the babysitting-pr watcher already prints the trimmed log of
every failed job on the head SHA. `${CLAUDE_SKILL_DIR}` is this skill's
directory; when the variable reaches you unexpanded, use the directory that
holds this SKILL.md:

```bash
bash "${CLAUDE_SKILL_DIR}/../babysitting-pr/scripts/pr-watch.sh" --pr <number|url> --failed-logs
```

A Dependabot "Errored with the message …" block is the same thing: the
message is the log.

## Classify

`${CLAUDE_SKILL_DIR}/../babysitting-pr/references/ci-heuristics.md` holds
the branch-caused / flaky split. Cross-check the failing file against
`git diff origin/<base>...<head> --name-only`.

Report first, in Japanese: the cause in one or two lines, the log lines
that show it, and the verdict — 修正 or 再実行.

## Act

- Branch-caused: fix on the PR head branch. When that branch is not checked
  out, or the user is working elsewhere in this checkout (「worktreeで」),
  use a worktree so their tree stays untouched:

  ```bash
  git fetch origin <head>
  git worktree add .claude/worktrees/<head-slug> <head> 2>/dev/null \
    || git worktree add --track -b <head> .claude/worktrees/<head-slug> origin/<head>
  ```

  Commit as a new commit (`formatting-commit`), plain push, and name the
  run to watch. Never amend under review.
- Flaky or unrelated: once every job on that SHA has finished,
  `gh run rerun <run-id> --failed`. Editing tests, timeouts, or CI config to
  force an unrelated failure green is not a fix.
- Not yours to fix — a dependency upgrade, infrastructure, anything outside
  the PR's scope: stop and say so with the evidence.
