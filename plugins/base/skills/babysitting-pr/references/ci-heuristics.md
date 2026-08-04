# CI Failure Heuristics

Read this when a snapshot contains `diagnose_ci_failure`. Telling a regression the
branch introduced apart from noise it has nothing to do with matters because the
correct response is opposite in each case.

## Get the evidence first

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/pr-watch.sh" --failed-logs
```

This prints the tail of every failed job's log on the head SHA, with the ISO
timestamps and the post-job cleanup section stripped — raw Actions logs end in
about twenty lines of git config and runner boilerplate that would otherwise
crowd out the failure. It uses the per-job log endpoint rather than
`gh run view --log-failed`, which stays empty until the whole workflow run
finishes, so a job that failed 30 seconds into a 15-minute run is diagnosable
immediately instead of 14 minutes later.

For more than the tail: `gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs`.

Never classify from a check name alone. "ShellCheck failed" is either a real
violation in a file the branch touched or a runner that could not install
shellcheck, and those need opposite responses. Cross-check the failing file
against `git diff origin/<base>...HEAD --name-only`.

## Fix in code (branch-related)

The failure points at something the branch changed: compile/typecheck/lint errors
in touched files, deterministic test failures in changed areas, snapshot
mismatches from intentional output changes, or a build/CI config change in the PR
failing deterministically.

## Rerun, do not patch (flaky or unrelated)

The evidence points outside the branch: dependency-fetch timeouts, runner
provisioning failures, GitHub Actions infrastructure errors, external service
outages or rate limits, or non-determinism in tests the branch does not touch.

Editing tests, dependency pins, CI config, or timeouts to make an unrelated
failure go green produces a PR whose diff no longer matches its purpose, and it
buries a problem someone else needs to see. Rerun within the budget, or stop and
report.

## Decision tree

1. PR merged or closed → stop.
2. Failed checks present:
   - Fetch failed-job logs before deciding anything.
   - A job failed while other checks are still pending → diagnose that job now.
   - Branch-related → fix, commit, push, keep watching.
   - Flaky/unrelated and all checks on the SHA are terminal → `--retry-failed`.
   - Flaky/unrelated with checks still pending → wait; a rerun would race the
     in-flight jobs.
   - Rerun budget exhausted (3 per head SHA) → stop and report the persistent
     failure with the log excerpt that shows why.
3. Genuinely ambiguous → one manual diagnosis attempt (reproduce locally if the
   command is cheap), then commit to a choice. Do not alternate between fixing
   and rerunning the same failure.
4. Review feedback outranks reruns: a review fix replaces the head SHA and
   retriggers CI anyway.

## Stop and ask instead of pressing on

Beyond the blockers the snapshot already reports, stop when the fix itself is not
yours to make: it needs a dependency upgrade, a change outside the PR's scope, or
it lives in infrastructure the user owns (self-hosted runner, external
credentials).
