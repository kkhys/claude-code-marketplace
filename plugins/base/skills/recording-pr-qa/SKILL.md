---
name: recording-pr-qa
description: Run a PR's manual test in a headless browser, capture each case as a screenshot or a captioned video with an in-video console, and place the evidence with the case list in the PR description — in the repository's template sections when it has them
argument-hint: "[PR number | PR URL] [--url <base URL>] [--post]"
disable-model-invocation: true
allowed-tools:
  - Bash(playwright-cli:*)
  - Bash(npx --no-install playwright cli:*)
  - Bash(gh:*)
  - Bash(git:*)
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
---

# Recording PR QA

Do the PR's manual test the way a reviewer would, in a headless browser, and
leave on the PR what the reviewer needs: the list of cases with what was
observed, and evidence that reads without sound. A case whose observable is
a state gets a screenshot; one whose observable is a transition gets a
chapter of one video — a chapter card per case, a caption bar saying what is
being done and what to expect, a console panel showing what each check read
from the page, and a callout on every click and key. Headless draws nothing
on the user's screen, so they keep working while it records.

## PR context

- Argument: $ARGUMENTS
- Current branch's PR: !`gh pr view --json number,url,title,state,isDraft,mergedAt,headRefName,headRefOid,baseRefName 2>/dev/null || echo "none"`
- CLI: !`command -v playwright-cli || echo "playwright-cli not on PATH"`

An argument naming a PR wins over the current branch; fetch the same fields
for it. `--url` names the environment and skips the choice in step 2.
`--post` posts the report without the confirmation in step 6. Without
`playwright-cli` on PATH, a project that depends on playwright carries the
same CLI as `npx --no-install playwright cli`.

## Steps

1. Read the change: `gh pr view <pr> --json title,body,files`,
   `gh pr diff <pr>`, then the touched files. Turn it into numbered cases,
   each one action a person can perform and one observable a person can
   see — rows added, a button gone, focus moved — plus the data the case
   needs (a list of 30 to paginate by 10). A body with a
   `### Test Cases (AI-Suggested)` list is the starting point: each item
   becomes a case, or goes to the not-checked list with the reason a
   headless browser cannot do it (a desktop app, another device, a wait the
   server measures). Name each case's observable: a state — a colour, a
   text, a layout, a variant to set beside its siblings — is filmed as a
   screenshot; a transition — rows loading, a bar closed and staying closed
   across a navigation, a position restored — is filmed as video. Done when
   every user-visible behaviour the PR adds or changes has a case. A PR
   with nothing to see in a browser (CI, docs, a refactor with no behaviour
   change) gets no evidence: say so and stop.

2. Pick the environment — first match wins, and the reason goes in the
   report:
   - `--url`.
   - A preview already built for this head: a URL the body names as the
     preview (`Testing Environment(s)`, the test procedure), a deployment
     whose `sha` is `headRefOid` with a success status carrying an
     `environment_url`
     (`gh api repos/{owner}/{repo}/deployments?sha=<headRefOid>`, then its
     statuses), a check run whose `detailsUrl` is a preview, or a bot
     comment with a preview URL posted after the head commit. A preview of
     an older commit is not this PR.
   - The production site, for a merged PR only: the `site` or `homepage`
     the project declares. Production is read-only — no form submits, no
     writes — and the analytics the site loads are blocked before the first
     action: `playwright-cli route "<pattern>" --status=204`, the pattern
     taken from `requests` after the first page load.
   - Local otherwise: `git worktree add <scratch>/wt <headRefOid>`, install
     when the lockfile changed, then build and serve the way the project's
     CLAUDE.md and package scripts say — a production build behind the
     preview server when the feature lives in build output (a search index,
     static pages), the dev server otherwise. Done when `curl` gets 200 from
     the URL and the page shows something the PR added.

   A login the cases need is the user's own. The state file is
   `${XDG_STATE_HOME:-$HOME/.local/state}/recording-pr-qa/<host>.json`;
   when it is missing, or a load lands on the login page, sign in once in a
   headed window:

   ```bash
   playwright-cli -s=qa-login open --headed --browser=chrome <login url>
   # the user signs in — ID and password, or Google SSO — and says so
   playwright-cli -s=qa-login state-save <state file> && chmod 600 <state file>
   playwright-cli -s=qa-login close
   ```

   The file carries the session cookie: it stays in that directory, never
   in a repository. Google may refuse to sign in to a browser under
   automation; the ID and password form is the sure path.

3. Rehearse without recording. One named session, kept to the end, opened
   with a config written to the scratch directory:

   ```json
   {
     "browser": {
       "launchOptions": { "channel": "chrome", "ignoreDefaultArgs": ["--disable-back-forward-cache"] },
       "initScript": ["${CLAUDE_SKILL_DIR}/scripts/qa-overlay.js"]
     },
     "outputDir": "<scratch>/qa"
   }
   ```

   ```bash
   playwright-cli -s=qa-<pr> open --config <scratch>/qa/cli.config.json
   playwright-cli -s=qa-<pr> state-load <state file>   # when the cases need the login
   playwright-cli -s=qa-<pr> resize 2560 1800
   playwright-cli -s=qa-<pr> goto <url>
   ```

   `channel: chrome` runs the installed Google Chrome, so nothing is
   downloaded. `ignoreDefaultArgs` restores bfcache, which Playwright
   turns off and a case riding on `history.back()` needs. `initScript`
   gives every page `window.__qa` (below) before any of its own scripts;
   what the body's test procedure sets up by hand before the app starts —
   a user agent pasted into the console, a flag written to storage — is a
   second file in that list, so every page starts in that state.
   `outputDir` keeps the files `snapshot` writes out of the repository;
   `--filename` paths stay relative to the working directory, so they are
   written absolute.

   The viewport is twice the 1280x900 layout because the init script zooms
   every page 2x: Playwright records at the CSS viewport size and never
   above it, and this is the one way to film at Retina density. Rects,
   `scrollY` and `mousemove` / `mousewheel` coordinates come in zoomed px,
   and media queries see 2560 — a breakpoint above 1280 is a layout the
   user's window would not show.

   A wait the case needs (three minutes idle) is Playwright's clock:
   `run-code "async page => { await page.clock.install() }"` before that
   case's `goto`, then `page.clock.fastForward('03:00')` at the wait; a
   wait the server measures cannot be shortened and goes to the
   not-checked list. Walk every case with `snapshot`, `find` and `eval`,
   and write down for each a selector for every target
   (`eval "el => el.outerHTML" <ref>` shows what to select by — refs are
   renumbered on every navigation, `e10` becomes `f2e10`), the exact
   commands, and the `eval` that reads its observable from the DOM. A
   check reads what the person sees — the same card at the same height —
   not a number the browser keeps: `scrollY` moved 42 px on a bfcache
   return while the view stayed put. Done when each case has run once and
   its check reads the right state — or the failure is understood.

4. Capture from one script. Write the rehearsed commands to `qa.sh` and run
   it in a single Bash call: a command takes well under a second, so the
   only pauses on film are the ones written in — the time between separate
   tool calls would be still video. The script starts with `goto <url>` and
   `eval "() => __qa.clear()" --raw`, names targets by selector, and takes
   the states first, then the transitions as one video:

   ```bash
   # a state: the element that holds it, so the bar stays out of frame
   playwright-cli -s=qa-<pr> screenshot "<selector>" --filename <dir>/<n>-<state>.png
   # a state that needs the whole viewport
   playwright-cli -s=qa-<pr> eval "() => __qa.hide()" --raw
   playwright-cli -s=qa-<pr> screenshot --filename <dir>/<n>-<state>.png
   playwright-cli -s=qa-<pr> eval "() => __qa.show()" --raw
   # the transitions
   playwright-cli -s=qa-<pr> video-start <dir>/qa.webm --size 2560x1800 --cursor
   playwright-cli -s=qa-<pr> video-show-actions --duration=800 --point-style="width: 18px; height: 18px; border-radius: 50%; background: rgba(255,90,95,.6)" --highlight-style="outline: 3px solid #ff5a5f; outline-offset: 2px"
   # per case
   playwright-cli -s=qa-<pr> video-chapter "<n>. <case>" --description="<expected>" --duration=1500
   playwright-cli -s=qa-<pr> eval "() => __qa.step('ケース <n>: <case>', '<what is done>。期待: <expected>')" --raw
   # ...the rehearsed actions...
   playwright-cli -s=qa-<pr> eval "() => { const s = <read the DOM>; return [__qa.check('<label>', s.rows, 20), __qa.check('<label>', s.more, true)]; }" --raw
   # after the last case
   playwright-cli -s=qa-<pr> video-stop
   playwright-cli -s=qa-<pr> close
   ```

   A screenshot is the element that holds the state — the app frame, the
   banner — at the 2x zoom, so it lands at Retina density. `--cursor`
   draws a pointer travelling to each action point and paces actions so it
   can; `--point-style` marks the point. `window.__qa`
   (`scripts/qa-overlay.js`) is a bar the page cannot see — inert,
   aria-hidden, closed shadow root, absent from snapshots — that survives
   navigations and draws a ripple wherever the mouse goes down:
   - `step(title, detail, hold = 1200)` — caption; resolves after `hold` ms
     so the viewer reads it before the action.
   - `check(label, actual, expected)` — writes `✓ label: actual` or
     `✗ label: actual (expected …)` in the panel and returns
     `{ pass, actual }`; `expected` is a value, a predicate, or absent for a
     truthy check.
   - `log(text)` — a plain line. `console.log/info/warn/error` and uncaught
     errors are mirrored on their own.
   - `place("top")` when the bar would hide the element under test;
     `hide()` / `show()` take it out of frame and back; `clear()` empties
     bar and panel.

5. Convert and look. Read every PNG. For the video:

   ```bash
   ffmpeg -i qa.webm -c:v libx264 -pix_fmt yuv420p -crf 28 -movflags +faststart qa.mp4
   ffmpeg -i qa.mp4 -vf "fps=1/3,scale=640:-1,tile=4x4" -frames:v 1 sheet.png
   ```

   Read `sheet.png`. Done when every screenshot shows its state whole, and
   every chapter card, caption and check line is legible with nothing
   clipped. GitHub takes 10 MB on a free plan and 100 MB on a paid one
   (about 6 MB per 75 s at this size): raise `-crf` before cutting cases.

6. Place. Take the current body (`gh pr view <url> --json body --jq .body`)
   and write the new one as `qa-body.md` in the directory that holds the
   files; change nothing outside the parts named here. The body decides
   the layout:
   - A template with `### Test Cases (Human-Verified)` and
     `## Screenshot(s)`: Human-Verified holds the section below from its
     first `<details>` through the not-checked list, with the cases as the
     template's checkboxes, `- [x] <n>. <case>: <observed>`, in place of
     the table; the evidence goes under `## Screenshot(s)` in the blocks
     of the section below; in
     `## Testing Environment(s)` the environment used is ticked, Preview
     with its URL in parentheses: `- [x] Preview environment (<url>)`.
     `### Test Cases (AI-Suggested)` is not touched. A section's content
     runs to the next heading or `---`, and a rerun replaces it. The cases
     are Human-Verified because the user checks the evidence before asking
     for review.
   - Otherwise the `## Manual QA` section below: replaced if an earlier
     run left one, appended after the author's text if not.

   Evidence is written as markdown references to the local files —
   `![<n> <state>](./<n>-<state>.png)`, and `![](./qa.mp4)` alone in its
   paragraph — and `gh pr edit` (≥ 2.99) rewrites each to its uploaded
   asset in place: an image keeps its alt, the video becomes the bare URL
   GitHub renders as a player. Paths in the body are relative to the body
   file. Show the draft, the images and the sheet; on the user's yes, or
   with `--post`, run from that directory:

   ```bash
   gh pr edit <url> --body-file qa-body.md --attach ./<n>-<state>.png --attach ./qa.mp4
   ```

   Variants of one state sit side by side at one width, which needs HTML
   gh does not rewrite: after the upload, read the body back and turn
   those images into `<img width="180" alt="<n> <state>" src="<asset url>" />`
   in a second `gh pr edit --body-file`. The section reads as the author's
   own test record, vetted before it is placed: no `[from Claude Code]`
   marker and no line naming who ran it.

7. Clean up — the session (`close`), the local server, the worktree — and
   report in Japanese: the PR URL, the cases, and what was not covered.

## Section format

The premise and what was not checked are folded, so the cases and the
evidence are what the reviewer sees first; the blank lines inside each
`<details>` are what make its Markdown render. A heading whose kind of
evidence the run has none of is left out.

```markdown
## Manual QA

<details>
<summary>対象・環境・判定</summary>

- 対象: PR head `<sha>`
- 環境: <which of step 2, and why>
- ブラウザ: Google Chrome（headless）、1280x900 を 2 倍密度で撮影
- 判定: <what each check read from the DOM>

</details>

| # | ケース | 期待 | 実測 | 結果 |
|---|---|---|---|---|

<details>
<summary>確認していないこと</summary>

- <what the cases leave out, and why>

</details>

### スクリーンショット

<n>. <state>（<caption>）

![<n> <state>](./<n>-<state>.png)

### 録画

動画の区切りカードの番号は上の表の # に対応します。字幕バーが操作と期待、右下のコンソールがチェック結果です。

![](./qa.mp4)
```
