# Watcher Output Reference

Semantics behind `pr-watch.sh` that the JSON itself does not show, plus the `gh`
calls underneath. The snapshot's field names are self-explanatory — read this for
the rules that produced them.

## Derived verdicts

`terminal`:

| Value | Meaning |
|---|---|
| `null` | Keep watching |
| `"mergeable"` | Ready-for-review PR met every merge precondition |
| `"draft_review_clean"` | Draft PR is green with no unresolved threads |
| `"merged"` / `"closed"` | PR left the review cycle |

`"mergeable"` requires `mergeable == MERGEABLE` plus a `merge_state_status` of
`CLEAN`, `UNSTABLE`, `BLOCKED`, or `HAS_HOOKS`. `BLOCKED` is accepted because,
with CI green and no open threads, what remains is a human approval.

`blockers`, each needing the user: `merge_conflict`, `retry_budget_exhausted`,
`copilot_round_cap`, `copilot_review_stalled`.

`actions`, in the order the loop should consider them: `stop_pr_merged`,
`stop_pr_closed`, `process_review_comment`, `diagnose_ci_failure`,
`retry_failed_checks`, `resolve_merge_conflict`, `update_branch`,
`request_copilot_review`, `stop_mergeable`, `stop_draft_review_clean`, `wait`.

## Field semantics worth knowing

- Check buckets: a `CheckRun` that is not `COMPLETED` is `pending`; `SUCCESS` and
  `NEUTRAL` are `pass`; `SKIPPED` is `skipped`; everything else — including
  `CANCELLED`, `TIMED_OUT`, and `ACTION_REQUIRED` — is `fail`. `ci.is_green`
  therefore means "nothing failed and nothing is still running".
- `ci.pending_checks` carries names only, and passing checks are not listed at
  all. Use `ci.failed_checks` and `--failed-logs` for anything failing.
- `reviews.threads` excludes comments belonging to a `PENDING` review, and drops
  a thread whose every comment is pending. Pending reviews are unsent drafts.
- `reviews.submitted` keeps only each reviewer's latest submission.
- `copilot.participant` is true when Copilot is currently requested or has
  reviewed at least once — the loop never pulls Copilot into a PR that never
  involved it. Only the review bot counts, not `copilot-swe-agent[bot]`.
- `copilot.request_age_seconds` is how long the outstanding request has gone
  unanswered, and is null when nothing is pending or when the state file predates
  the field — the stall blocker fails open rather than crying wolf.
- `local.*` describes the working copy the script ran in. When watching another
  repository's PR via `--pr <url>`, those fields describe the wrong checkout.
- `new_thread_ids` is relative to every earlier poll in this state file, not just
  the previous one.

## State file

`${TMPDIR:-/tmp}/claude-babysit-pr/<owner>-<repo>-<pr>.json`

```jsonc
{
  "pr": 76,
  "fingerprint": { /* last observed; compared to produce `changed` */ },
  "known_thread_ids": ["PRRT_..."],    // union across polls
  "retries": { "<head-sha>": 1 },      // rerun cycles, per SHA
  "copilot_rounds": 2,                 // review requests, per PR
  "copilot_requested_at": 1785899000,  // epoch of the last request; drives the stall blocker
  "updated_at": "2026-08-04T02:11:09Z"
}
```

Every action that spends budget writes its counter in the same step it acts, so
an interrupted session cannot silently reset a budget. `--reset-state` deletes
the file; `--state-file` keeps parallel watchers from sharing one.

## Underlying gh calls

One GraphQL query per poll covers PR metadata, review threads, submitted reviews,
requested reviewers, and the head commit's `statusCheckRollup`. `mergeable` is
re-queried up to three times when it returns `UNKNOWN`, since GitHub computes
mergeability lazily on first read.

REST is used only for actions:

| Purpose | Call |
|---|---|
| Failed jobs for a run | `gh api repos/{o}/{r}/actions/runs/{run_id}/jobs` |
| Single job log (plain text) | `gh api repos/{o}/{r}/actions/jobs/{job_id}/logs` |
| Rerun failed jobs only | `gh run rerun {run_id} --failed` |
| Request Copilot review | `gh pr edit {n} --add-reviewer "@copilot"` |

`gh pr edit --add-reviewer` re-requests an existing reviewer as well as adding a
new one, which is what makes the Copilot loop possible from the CLI. It needs
`gh` 2.88.0 or newer; the script checks and fails with a clear message.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Missing dependency, unresolvable PR, or `gh` too old |
| 2 | Bad arguments |
| 3 | Budget exhausted (rerun budget or Copilot round cap) |
| 4 | Copilot review request rejected by GitHub |

Exit 3 and 4 are expected outcomes, not crashes: report them as blockers.

## Tests

`scripts/test-pr-watch.sh` runs offline against fixtures, covering the terminal
rules, check bucketing, pending-review filtering, the Copilot loop and its bot
identity, change detection, budget persistence, and the version gate. Run it
after touching `snapshot.jq` or `pr-watch.sh`:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/test-pr-watch.sh"
```
