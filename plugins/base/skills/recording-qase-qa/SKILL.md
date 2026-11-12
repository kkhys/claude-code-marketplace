---
name: recording-qase-qa
description: Run a PR's manual test against its Qase cases — record them into the QA run with a clip per case, create the missing cases, and turn the repeatable ones into a Playwright spec on a stacked PR
argument-hint: "[PR number | PR URL] [what to correct in a case]"
disable-model-invocation: true
allowed-tools:
  - Bash(playwright-cli:*)
  - Bash(npx --no-install playwright cli:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Bash(jq:*)
  - Bash(ffmpeg:*)
  - Bash(ffprobe:*)
  - Bash(curl:*)
  - Bash(mkdir -p:*)
  - Bash(chmod 600:*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
---

# Recording Qase QA

`recording-pr-qa` leaves the evidence of a manual test on the PR, where it
ends with the PR. This skill runs the same test against Qase so it lasts:
every case filmed is a Qase case, its result and clip sit in the QA run,
and a case that can repeat becomes a spec CI runs from then on. The Qase
case ID is the thread — on the chapter card, in the PR body, on the result,
in `qase(<id>, …)`.

## PR context

- Argument: $ARGUMENTS
- Current branch's PR: !`gh pr view --json number,url,title,state,isDraft,headRefName,headRefOid,baseRefName,author 2>/dev/null || echo "none"`
- Viewer: !`gh api user --jq .login 2>/dev/null || echo "unknown"`

An argument naming a PR wins over the current branch; fetch the same fields
for it. Text after the PR is a correction to a case from an earlier run:
start at [Correcting a case](#correcting-a-case). The PR is the user's own:
its body carries the run and the cases. For an `author.login` other than
the viewer, stop and name `/recording-pr-qa --review`.

`allowed-tools` lets `bash` and `gh` run without a prompt, so nothing but
the three confirmations below stops a write to Qase or GitHub: show what
will be written, wait for the user's yes, and take that yes for the writes
shown and no others.

## Qase API

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/qase-api.sh" [--all] <METHOD> <path> [body.json]
bash "${CLAUDE_SKILL_DIR}/scripts/qase-api.sh" upload <CODE> <file>...
```

Paths are relative to `/v1`; `--all` follows the offset of a list and prints
its entities as one array. The token is `QASE_API_TOKEN`: when the script
reports it missing, stop and ask the user to set it. A failed call prints
the body, whose `errorFields` names the field.

| Call | Use |
| - | - |
| `--all GET /suite/<CODE>` | Suites with `parent_id` |
| `--all GET /case/<CODE>?suite_id=<id>&status=actual` | A suite's cases with their steps; `search=<phrase>` in place of `suite_id` looks across the project |
| `--all GET /shared_parameter` | The workspace's shared parameters, with the `id` a case attaches |
| `POST /case/<CODE>` | Create: `title`, `suite_id`, `preconditions`, `steps[]` of `action` / `expected_result` / `data`, `parameters[]`, `isManual`, `isToBeAutomated` |
| `PATCH /case/<CODE>/<id>` | Edit; `steps` replaces the list, so send all of them |
| `DELETE /case/<CODE>/<id>` | Delete, with its execution history |
| `GET /run/<CODE>/<id>?include=cases` | A run: its case IDs and `stats` |
| `POST /run/<CODE>` | Create: `title`, `description`, `cases[]`, `tags[]`; `PATCH /run/<CODE>/<id>` edits the first two and the tags |
| `upload <CODE> <file>…` | Attachments, 20 files of 32 MB at most; `result[].hash` goes on a result |
| `POST /result/<CODE>/<run>/bulk` | `{"results": [...]}`, each `case_id`, `status`, `time_ms`, `comment`, `attachments[]`, `steps[]`, `param` |
| `GET /result/<CODE>?run=<id>` | A run's results with their `hash`; `DELETE /result/<CODE>/<run>/<hash>` removes one |

What the field names do not tell:

- `suite_id` matches that suite alone. A parent suite holds no cases of its
  own; its children are the rows with its `parent_id`.
- `search` is a substring of the title: one noun or exact phrase per call,
  written without a space.
- Lists come oldest first. The recent runs are the last page: read
  `result.total` with `limit=1`, then `limit=5&offset=<total - 5>`.
- A run's case list is fixed when the run is created — `PATCH /run` takes
  the title, description and tags only — so cases are created before the
  run that holds them.
- A result step is addressed by `position`, the number the case's own step
  carries, and its `status` is `passed`, `failed` or `blocked`: a step not
  performed is `blocked` with the reason in its `comment`.
- Automation is `isManual` with `isToBeAutomated`; the integer `automation`
  is deprecated.
- Links: a run is `https://app.qase.io/run/<CODE>/dashboard/<id>`, a case
  `https://app.qase.io/case/<CODE>-<id>`.

## Steps

1. **Scope.** Read the change as step 1 of
   `${CLAUDE_SKILL_DIR}/../recording-pr-qa/SKILL.md` does, and list the
   behaviours it adds or changes. A PR with nothing to see in a browser
   gets no run: say so and stop. The Qase facts come from the repository:
   - The project code and the suite of each feature: the QA doc the PR
     template points to (`docs/develop/qa-impact-scope.md` in
     miitel-softphone, where v2 is `MS` and v3 `MS3`) and the body's Impact
     Scope block. Without either, ask the user for the code and the suites.
     A scope that names no suite — a foundation change, every feature —
     is the user's call too: ask which suites the run takes. A change in
     two projects is a run in each, done one after the other; the body's
     `Qase:` line takes one URL and CI reads only the first, so ask which
     run goes there.
   - The automated cases: `git grep -nE "qase\(" <headRefOid> -- <spec dir>`.
     Case IDs are per project, so read only the specs that report to this
     one: the CI workflow maps a project code to a Playwright project and
     its directory (in miitel-softphone `e2e/*.e2e.ts` is `MS` and
     `e2e/v3/` is `MS3`). A `test.skip(qase(` is a case CI skips, so it
     counts as not automated.

   Fetch every actual case of the suites the Impact Scope names, direct and
   indirect, and class each one — by its title first, by its steps when
   the title touches a changed behaviour:

   | Class | The case | What happens to it |
   | - | - | - |
   | automated | is wrapped by `qase(` in a spec that runs | In the run; CI executes and reports it |
   | record | has steps that exercise a changed behaviour, all of which a headless browser can perform | Steps 4 and 5 |
   | manual | is any other | In the run, untested: QA's share. One that exercises a changed behaviour gets the reason headless cannot do it |
   | new | does not exist: a changed behaviour no case covers | Step 2, then as record or manual |

   An automated case that exercises a changed behaviour is filmed too, for
   the PR's reader, and gets no result from this skill: CI reports it. An
   automated case Qase still marks `isManual: true` is drift: list it, and
   on the yes mark it the way its automated neighbours in the suite are
   marked (`isManual: false`, the tag they carry).

   Done when every changed behaviour names its case IDs or `new`, and every
   fetched case has a class.

2. **Draft the missing cases.** Search before drafting: a `search=` per
   noun of the behaviour, and the suites already fetched. A near
   match that lacks one step is extended with `PATCH`; a behaviour nothing
   covers is a new case, `isManual: true`, with `isToBeAutomated: true`
   when step 6 can take it. Invoke `writing-qase-cases` before drafting or
   editing a case: it holds only what lasts as long as the behaviour —
   nothing of the PR, the ticket, a feature flag or the environment — and
   its variants are parameters.

   Show the class table of step 1, each draft beside its nearest existing
   cases, and the run step 3 would create, and wait for the yes
   (confirmation 1). Then `POST` the cases and keep their IDs. With nothing
   to write — every behaviour covered, the run already there — show the
   table and go on.

3. **Open the run.** A run ID on the body's `Qase:` line — digits, where
   the template has `XXX` — is the run: read it with `?include=cases`. A
   case of step 1 or 2 missing from it is named to the user, who adds it in
   Qase. Otherwise create the run under the yes of step 2, with every case
   of steps 1 and 2 — this is the run QA works in, so what CI and this
   skill leave untested is exactly QA's share — and with the title,
   description and tags the project's recent runs for a PR carry.

   The run holds what belongs to this PR, so the cases stay free of it.
   Its description ends with `Created cases: <CODE>-<id>, …`, the cases
   this PR made: that line is what lets a rerun delete those and no
   others. On a run that already exists, append it with `PATCH /run`. The
   flags the PR's behaviours sit behind, with their state in the recorded
   environment, go in the description too.

   The run's URL stays out of the PR body until step 7. A CI workflow that
   reads it there (`qase-e2e.yml` in miitel-softphone) starts the automated
   cases as soon as it appears, on the test account the recording and the
   spec's local runs use, where E2E runs are kept one at a time.

4. **Record.** Run steps 2 to 5 of
   `${CLAUDE_SKILL_DIR}/../recording-pr-qa/SKILL.md` — environment,
   rehearsal, capture, conversion — for the cases to film. The PR
   is the one above and none of that file's flags is set; the paths it
   writes relative to its own skill directory resolve in
   `${CLAUDE_SKILL_DIR}/../recording-pr-qa/`. What differs here:

   - **Quiet account.** Film while no E2E run uses the test account: one
     already going on this PR (`gh pr checks <pr>`) is waited for first.
   - **Environment.** A repository with Playwright specs is recorded where
     the specs run, so the rehearsed selectors and waits hold in step 6:
     the `baseURL` and `webServer` command of `playwright.config.ts`, the
     storage state its setup project writes
     (`playwright test --project=<setup>`, loaded with `state-load`), and
     the `use` options the CLI config can carry — `ignoreHTTPSErrors` and
     `locale` under `contextOptions`, launch `args` beside the two the
     recording needs. A checkout already on `headRefOid` serves as it is,
     with its env files and installed dependencies; no worktree.
   - **Script.** The Qase steps are the script. Each step is one caption
     (`__qa.step`) and one planned check, in the case's order, so every
     step ends with a status; a step that repeats an action for another
     `data` (compact, wide) is performed once per `data`. A parameterized
     case is performed once per row of its parameters, each row a chapter
     with its own mark, `<id>-<row number>`.
   - **Chapters.** Every case is a chapter, a state held on screen as under
     `--video-only`, and a state still gets its screenshot for the PR. The
     card carries the ID: `__qa.chapter('<n>. <CODE>-<id> <title>', '<expected>')`.
   - **Marks.** `qa.sh` writes the clock to `<dir>/marks` before
     `video-start`, before each chapter, and before `finish`, so the take
     can be cut by case:

     ```bash
     now() { perl -MTime::HiRes=time -e 'printf "%.2f\n", time'; }
     echo "start $(now)" >> <dir>/marks   # then video-start
     echo "<id> $(now)" >> <dir>/marks    # then that case's __qa.chapter
     echo "end $(now)" >> <dir>/marks     # then __qa.finish
     ```

   - **Clips.** After the conversion, one MP4 per case, from its mark to
     the next, as `<dir>/case-<id>.mp4`:

     ```bash
     bash "${CLAUDE_SKILL_DIR}/scripts/cut-case-clips.sh" <dir>/marks <dir>/qa.webm
     ```

     Done when each clip's contact sheet opens on its own chapter card and
     ends on its last check. A clip over Qase's 32 MB is re-encoded with
     `-crf 28`.

5. **Write the results.** One entry in `results.json` per filmed case that
   is not automated: `status` from its checks (`failed` when any check
   failed), `time_ms` the clip's length, a `steps` entry per Qase step with
   what the check read as its `comment`, and a `comment` naming the PR
   head, the environment and account, and every substitution of test data.
   A parameterized case gets an entry per row: `param` names that row's
   values (`{"<parameter title>": "<value>", …}`), and for a group
   `param_groups` lists the group's titles (`[["<title>", …]]`). Draft the
   PR body of step 7 beside it. Show both with the clips' sheets and the
   screenshots, and wait for the yes (confirmation 2). Then `upload` the
   clips, put each `hash` in its case's `attachments`, and `POST` the bulk.
   Done when the run's `stats` count those results — a row each for a
   parameterized case — and `?include=cases` lists every recorded case; a
   case or a row the run does not show is named to the user.

6. **Write the spec**, while nothing has started CI yet. A recorded case
   qualifies when it passed and leaves the shared test data as it found
   it — no real call placed, no record created that the test cannot
   remove. The others keep `isToBeAutomated` as drafted, and the report
   says which and why.

   The spec is written in a checkout on the PR's head branch; from any
   other, name the branch in the report and go to step 7. Write it the way
   the repository writes its own: through its skill for E2E specs when it
   has one (`writing-playwright-e2e-tests` in miitel-softphone), else after
   the nearest existing spec. Hand over, per case, the Qase ID and title,
   the rehearsed selectors and commands, and the expressions its checks
   read — the rehearsal is the draft, restated in the repository's
   selector convention. The title is `qase(<id>, '<title>')` with the ID
   Qase returned. That skill's own PR step gives way to step 8, and the
   file stays uncommitted until then.

   The spec ships when it holds three runs in a row:

   ```bash
   <the project's playwright command> <file> --grep "Qase ID: <id>\)" --repeat-each=3
   ```

   The grep is the title the reporter writes, the one CI picks a run's
   cases by, so a pass also shows that the ID links. A spec that does not
   hold is left out, with what made it unstable.

7. **Place on the PR**, under the yes of step 5, as step 6 of
   `recording-pr-qa` does in the body, with three additions in the same
   edit: every case line or row carries its link,
   `[<CODE>-<id>](<case url>)`; the not-checked list names the manual
   cases that exercise a changed behaviour; and the `Qase:` line carries
   the run's URL. This edit starts CI on the automated cases, which is why
   it follows the recording and the spec's runs.

8. **Stack the spec PR**, when step 6 left a spec. Show the cases, the
   file and the branch, and wait for the yes (confirmation 3). The verdict
   is given — a stack of two, the PR's head branch below and the spec's
   branch on top — so build it through `creating-stacked-pr` from its
   Phase 3: `gh stack init <headRefName> <spec branch>` adopts the first,
   whose PR stays as it is, and creates the second on it (on a head
   already in a stack, `gh stack add <spec branch>`). The branch name,
   the commit, the title and the body follow the repository's own
   conventions and PR skill when it has one
   (`softphone-team:creating-pr`), else `creating-pr`. The body carries no
   run URL: it would start a second E2E run on the account, and step 6
   already ran the spec by its ID.

9. **Clean up and report**, as step 7 of `recording-pr-qa`, plus: the run
   URL with its counts per class, the cases created or edited, the cases
   left to QA with the reason for each, and the spec PR.

## Correcting a case

A rerun finds the earlier one through the run on the `Qase:` line and the
case links in the body. With no correction it records again at the new
head and posts new results; Qase keeps the earlier ones as history.

A correction — a reviewer found a case wrong — changes the case first,
under its own yes:

- **Edit**: show each changed field before and after, then `PATCH` the
  case. Any case in the run may be edited.
- **Delete**: only a case the run's `Created cases:` line names; take it
  off that line afterwards. The delete takes the execution history with
  it and cannot be undone, so the yes names the case. A wrong case from
  elsewhere is reported and left to its owner.

Then bring everything keyed by that ID in line, in the same run: record
the edited case again and post its result; remove the earlier result whose
clip shows the wrong steps; rewrite the case's line in the PR body; and in
the spec PR, change or remove the test wrapped by `qase(<id>` as a new
commit.
