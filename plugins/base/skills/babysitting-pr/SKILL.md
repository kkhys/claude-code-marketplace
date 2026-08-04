---
name: babysitting-pr
description: >-
  Monitor a pull request until it is genuinely mergeable — long-poll CI checks,
  review threads, and merge state; fix branch-caused CI failures and actionable
  review comments autonomously; re-request Copilot review after every fix round
  until Copilot stops commenting.
when_to_use: >-
  Trigger whenever the user wants a PR watched rather than checked once —
  "PR 監視して", "CI 見張ってて", "マージできるようになるまで見てて",
  "レビューコメントがなくなるまで対応して", "babysit the PR", "watch CI until
  it's green", "keep handling review comments until there are none left". Also
  use right after opening a PR when the user wants it carried to a mergeable
  state without further prompting, or when they ask to keep fixing Copilot
  feedback until Copilot stops finding things.
argument-hint: "[PR number | PR URL]"
---

# Babysitting a PR

Carry one PR to a finished state without handing control back early. A single
quiet snapshot means nothing — checks queue, Copilot reviews arrive minutes
after a push, and mergeability is computed lazily. The job is only over when a
terminal condition below is actually met.

## PR Context

!`gh pr view --json number,title,url,state,isDraft,mergeStateStatus 2>/dev/null || echo "No open PR found for the current branch"`

## What "done" means

The PR's draft status when babysitting starts selects the goal:

| Started on | Terminal condition |
|---|---|
| Ready for review | CI green, no merge conflict, no unresolved review threads, Copilot loop closed, `mergeable` is `MERGEABLE` |
| Draft | CI green, no unresolved review threads, Copilot loop closed |

Reviewer approval is deliberately not required. A PR that is green, conflict-free
and review-clean but `BLOCKED` on a required approval has reached the point where
only a human can act — report it as ready and stop rather than polling forever.

Also stop when:

- The PR is merged or closed — report the terminal state immediately.
- A blocker needs the user: merge conflict, exhausted rerun budget, Copilot round
  cap, review feedback that requires a product or design decision, `gh` auth or
  push failure, or unrelated uncommitted changes in the worktree.

Everything else is a progress state, including a push, a rerun, and a green CI
run. Never emit a final summary because a snapshot happened to look calm.

## The watcher

`pr-watch.sh` turns PR state into one JSON snapshot with a `terminal` verdict,
a `blockers` list, and an `actions` list. Trust those derived fields instead of
re-deriving mergeability from raw fields — they encode the terminal rules above
and are covered by `scripts/test-pr-watch.sh`.

```bash
# One snapshot (start here to learn the current state)
bash "${CLAUDE_SKILL_DIR}/scripts/pr-watch.sh" --once

# Block until something actually changes (the normal way to wait)
bash "${CLAUDE_SKILL_DIR}/scripts/pr-watch.sh" --wait

# Trimmed logs for every failed job on the head SHA
bash "${CLAUDE_SKILL_DIR}/scripts/pr-watch.sh" --failed-logs

# Rerun only the failed jobs (budget: 3 cycles per head SHA)
bash "${CLAUDE_SKILL_DIR}/scripts/pr-watch.sh" --retry-failed

# Ask Copilot for a fresh review of the current head SHA (cap: 5 rounds)
bash "${CLAUDE_SKILL_DIR}/scripts/pr-watch.sh" --request-copilot-review
```

Add `--pr <number|url>` to target a PR other than the current branch's.

`--wait` polls every 30s and returns as soon as the state fingerprint changes,
or after 7 minutes with `timed_out: true`. **Call it with the Bash tool's
`timeout` set to `450000`** — the default 2-minute tool timeout would kill the
long-poll and turn every wait into a wasted call. Long-polling is what makes an
hour of monitoring cost a handful of tool calls instead of a hundred.

Rerun and Copilot-round counters persist in a state file, so budgets hold across
calls. `--reset-state` clears them when the user wants a clean slate.

Read `references/watcher-output.md` for the snapshot schema and the raw `gh`
commands behind it — consult it when you need a field the loop below does not
mention.

## Preflight

1. Snapshot with `--once`, adding `--pr $ARGUMENTS` when the user named a PR
   number or URL. With no argument the PR is inferred from the current branch.
   If `pr.state` is not `OPEN`, report and stop.
2. Note `pr.is_draft` — it fixes the goal for the whole session.
3. If `local.dirty` is true, inspect `git status`. Unrelated uncommitted changes
   make editing unsafe: stop and ask. Nothing else in this skill is allowed to
   discard someone's work in progress.
4. If `local.on_head_branch` is false, check out the PR head branch — every fix
   has to land on the branch under review.

## The loop

Each iteration works from one snapshot, acts on at most one thing, then takes a
fresh snapshot. Ordering matters, so follow it top-down:

1. `stop_pr_merged` / `stop_pr_closed` → report and stop.
2. Non-empty `blockers` → report the blocker with enough detail to act on, and
   stop. Do not improvise around it.
3. `process_review_comment` → handle review feedback (next section). Review
   fixes come before reruns because the fix commit replaces the head SHA, and
   rerunning checks on a SHA you are about to abandon burns CI minutes.
4. `diagnose_ci_failure` → classify, then fix or rerun (see
   `references/ci-heuristics.md`).
5. `update_branch` → the base branch moved ahead; merge it in (see below).
6. `request_copilot_review` → re-request Copilot and keep watching.
7. `stop_mergeable` / `stop_draft_review_clean` → report the terminal summary
   and stop.
8. `wait` → `--wait` again.

After any push, rerun, or review request, go straight back to step 1 with a
fresh snapshot. A push is the middle of the job, not the end of it.

When `--wait` returns `timed_out: true` with no change, emit a one-line
heartbeat (elapsed time, what is pending) and wait again. Keep updates sparse:
report state *changes*, not every poll.

## Review comments

`reviews.threads` in the snapshot already excludes comments attached to a
`PENDING` review — those are someone's unsent draft, and acting on them would
expose feedback the author has not published yet.

For each round of feedback:

1. Invoke `reading-unresolved-pr-comments` for a fix plan. It reads the deeper
   intent behind each comment, which is what keeps a fix from bouncing back in
   the next review round.
2. Invoke `fixing-review-comments` to implement, verify, commit, push, and reply
   to each thread. It runs the project's tests and linter before pushing —
   pushing red code to a PR under review wastes the reviewer's time. Tell it to
   land a **new commit and a plain push**, overriding its default of amending
   review-feedback fixes: see Git safety below for why.
3. Invoke `resolving-pr-comments` with the thread IDs you addressed — always the
   explicit list, never a bulk resolve. Resolving every unresolved thread would
   also close ones you deliberately left alone.

Babysitting resolves threads it has addressed, which is a deliberate exception
to the default "resolution is the reviewer's prerogative" rule in
`fixing-review-comments`. The user asked for a loop that converges, and an
addressed thread that stays open keeps the terminal condition out of reach
forever.

Do not fix, reply to, or resolve a thread when the comment needs a decision that
is not yours to make — a product or design call, a disagreement about the
approach, or an ambiguous request. Surface it with a suggested response and stop.
Guessing here produces code the user did not ask for and a reply that commits
them to a position.

## Copilot review loop

When Copilot participates in the review, keep the loop running until it stops
finding things:

1. Address Copilot's comments like any other feedback, then push.
2. Re-request the review: `--request-copilot-review`. The new head SHA needs its
   own review; Copilot does not re-review automatically unless the repository
   enabled review-on-push.
3. Wait for Copilot's review of the new SHA (`copilot.reviewed_head_sha`), then
   handle whatever it found.
4. Repeat until Copilot reviews the head SHA with no unresolved comments.

The snapshot only asks for a re-request when Copilot is already a participant —
either currently requested or has reviewed at least once. Do not add Copilot to
a PR that never involved it.

Two guards, both surfaced as blockers rather than silently swallowed:

- Copilot repeats comments it has already made, including dismissed ones. If a
  round produces only feedback you already addressed on this branch, treat the
  loop as converged, say so, and stop re-requesting.
- After 5 rounds (`copilot.rounds_cap`), stop and report. A loop that will not
  converge is information the user needs, not something to grind on.

If `--request-copilot-review` fails because Copilot code review is unavailable on
the repository, note it once and continue babysitting without the Copilot loop.

## Comment attribution

Comments are posted with the user's own token, so GitHub shows them as the user's.
Every one therefore starts with `[from Claude Code]`, or a reviewer reads an
agent's reply as a personal commitment from the user. The reply and review scripts
prepend it; add it yourself when using plain `gh pr comment`.

## Merge conflicts and stale branches

`update_branch` (`BEHIND`) is safe to handle: merge the base branch into the head
branch and push. No history is rewritten.

```bash
git fetch origin && git merge "origin/<base_ref>" && git push
```

A real conflict (`merge_conflict`) is a blocker. Resolving someone's conflict
means choosing between two intents, and getting it wrong silently reverts work.
Report the conflicting files and stop.

## Git safety

- Work only on the PR head branch.
- Add new commits; never amend or rebase during babysitting. This overrides the
  usual "amend when addressing review feedback" preference from
  `formatting-commit`: mid-review, a force-push detaches existing review comments
  from their lines and erases the per-round diff a reviewer uses to check that
  their feedback was applied. Between rounds, that history *is* the answer.
- Follow `formatting-commit` for message format. One commit per fix round, scoped
  to what that round fixed.
- Push with plain `git push`. If it is rejected, someone else pushed — fetch,
  re-snapshot, and reconsider rather than forcing.

Out of scope, no matter how autonomous the rest of the loop is: merging the PR,
closing or reopening it, and toggling draft / ready-for-review. Those are
statements about the work being finished, which only the user gets to make. Stop
at the terminal state and report.

## Reporting

While monitoring: one line per state change. When CI first goes green on a SHA,
say so once — repeating it on every poll buries the signal.

Final summary (Japanese, as always):

- 終了理由 (terminal state or blocker)
- 最終 SHA と CI 状況
- マージ可能性 / コンフリクト状況
- push した修正 (commit ごとに 1 行)
- flaky リトライ回数 / Copilot レビューラウンド数
- 残っている未解決項目、および人間の対応が必要なこと

## References

- CI failure classification and the fix-vs-rerun-vs-stop decision tree:
  `references/ci-heuristics.md`
- Snapshot schema, state file layout, and underlying `gh` commands:
  `references/watcher-output.md`
