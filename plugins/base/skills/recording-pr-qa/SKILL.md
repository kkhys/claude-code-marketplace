---
name: recording-pr-qa
description: Run a PR's manual test in a headless browser, capture each case as a screenshot or a captioned video with an in-video console, and place the evidence with the case list in the PR description — in the repository's template sections when it has them — or, on a PR the user reviews, in their pending review
argument-hint: "[PR number | PR URL] [--url <base URL>] [--review] [--post] [--video-only]"
disable-model-invocation: true
allowed-tools:
  - Bash(playwright-cli:*)
  - Bash(npx --no-install playwright cli:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
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
chapter of one video — a chapter card per case, a caption card saying what
is being done and what to expect, a progress bar over the cases, a
checklist that ticks as each check reads the page, a pointer that travels to each
click, keycaps for what is typed, and a closing card with the tally. Headless draws nothing
on the user's screen, so they keep working while it records.

## PR context

- Argument: $ARGUMENTS
- Current branch's PR: !`gh pr view --json number,url,title,state,isDraft,mergedAt,headRefName,headRefOid,baseRefName,author 2>/dev/null || echo "none"`
- Viewer: !`gh api user --jq .login 2>/dev/null || echo "unknown"`
- CLI: !`command -v playwright-cli || echo "playwright-cli not on PATH"`

An argument naming a PR wins over the current branch; fetch the same fields
for it. `--url` names the environment and skips the choice in step 2.
`--review`, or an `author.login` other than the viewer, places the report
in the user's pending review instead of the PR body (step 6). `--post`
posts the report without the confirmation in step 6. `--video-only` makes
the video and stops: every case is a chapter, a state held on screen
instead of a screenshot, nothing is placed on the PR, and the report gives
the MP4's path. Without
`playwright-cli` on PATH, a project that depends on playwright carries the
same CLI as `npx --no-install playwright cli`. The scratch directory is the
session's scratchpad, or `mktemp -d` without one: outside the repository,
so nothing the run writes lands in a commit.

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
   mkdir -p -m 700 <state file's directory>
   playwright-cli -s=qa-login open --headed --browser=chrome <login url>
   # the user signs in — ID and password, or Google SSO — and says so
   playwright-cli -s=qa-login state-save <state file> && chmod 600 <state file>
   playwright-cli -s=qa-login close
   ```

   The file carries the session cookie: it stays in that directory, never
   in a repository. `-m 700` keeps the directory private: `state-save`
   would create it with the default mode, and writes the file with the
   default mode before the `chmod`. Google may refuse to sign in to a
   browser under automation; the ID and password form is the sure path.

3. Rehearse without recording. One named session, kept to the end, opened
   with a config written to the scratch directory:

   ```json
   {
     "browser": {
       "launchOptions": {
         "channel": "chrome",
         "args": ["--force-device-scale-factor=2", "--window-size=1280,987"],
         "ignoreDefaultArgs": ["--disable-back-forward-cache"]
       },
       "contextOptions": { "viewport": null },
       "initScript": ["${CLAUDE_SKILL_DIR}/scripts/qa-overlay.js"]
     },
     "outputDir": "<scratch>/qa"
   }
   ```

   ```bash
   playwright-cli -s=qa-<pr> open --config <scratch>/qa/cli.config.json
   playwright-cli -s=qa-<pr> state-load <state file>   # when the cases need the login
   playwright-cli -s=qa-<pr> goto <url>
   playwright-cli -s=qa-<pr> eval "() => [devicePixelRatio, innerWidth, innerHeight]" --raw   # 2, 1280, 900
   ```

   `channel: chrome` runs the installed Google Chrome, so nothing is
   downloaded. `ignoreDefaultArgs` restores bfcache, which Playwright turns
   off and a case riding on `history.back()` needs. `initScript` gives every
   page `window.__qa` (below) before any of its own scripts; what the body's
   test procedure sets up by hand before the app starts — a user agent
   pasted into the console, a flag written to storage — is a second file in
   that list, so every page starts in that state. The init script is read
   when the session opens: after editing a file in that list, `close` and
   `open` again. `outputDir` keeps the files `snapshot` writes out of the
   repository; `--filename` paths stay relative to the working directory, so
   they are written absolute.

   Retina density comes from the browser: `--force-device-scale-factor=2`
   makes every CSS pixel two device pixels, and the screencast records
   2560x1800 for the 1280x900 viewport. It holds only while Playwright
   emulates nothing — `viewport: null` in the config and no `resize`, either
   of which sets a device scale of 1 and halves the video's density. The
   `eval` above reads 2, 1280, 900; `--window-size` is the window, 87 px
   taller than the viewport it leaves. The page is not zoomed: rects, scroll
   offsets and media queries are the ones the user's browser has, and what
   the app positions from a measured rect — a tooltip, a popover, a menu —
   lands where it does for the user.

   A mobile or narrow-width case stays in this session: `__qa.device(390,
   844, 'iPhone 15')` puts the page in a frame of that size on a plain
   stage. Media queries see the frame's width, the cards move beside the
   device instead of over it, and a second call with another size resizes
   the frame on film; `__qa.device()` returns to the full page. While the
   stage is up, `__qa.point`, `__qa.scroll` and `__qa.frame()` — the
   device's document, for the checks — address the device, `type` and
   `press` go to its focused field, and a click goes through a frame
   locator: `run-code "async page => { await
   page.frameLocator('#qa-device').locator('<selector>').click(); }"`. The
   frame is same-origin, so the login holds. A site that forbids framing
   itself (`X-Frame-Options: DENY`, `frame-ancestors 'none'`), or a case
   that depends on the mobile user agent or on touch, is a second session
   instead — `--window-size=<width>,<height + 87>` and
   `contextOptions.userAgent` in its config — filmed as its own video.

   A wait the case needs (three minutes idle) is Playwright's clock:
   `run-code "async page => { await page.clock.install() }"` before that
   case's `goto`, then `page.clock.fastForward('03:00')` at the wait; a wait
   the server measures cannot be shortened and goes to the not-checked list.
   Walk every case with `snapshot`, `find` and `eval`, and write down for
   each a selector for every target (`eval "el => el.outerHTML" <ref>` shows
   what to select by — refs are renumbered on every navigation, `e10`
   becomes `f2e10`), the exact commands, and the `eval` that reads its
   observable from the DOM. A check reads what the person sees — the same
   card at the same height — not a number the browser keeps: `scrollY` moved
   42 px on a bfcache return while the view stayed put. During rehearsal,
   check a click's pointer and rings against its target. Done when each case
   has run once and its check reads the right state — or the failure is
   understood.

4. Capture from one script. Write the rehearsed commands to `qa.sh` and run
   it in a single Bash call: a command takes well under a second, so the
   only pauses on film are the ones written in — the time between separate
   tool calls would be still video. Give that call a `timeout` above the
   script's run time, its holds plus about a second per command: the
   two-minute default kills it mid-run. The script starts with `goto <url>`
   and `eval "() => __qa.clear()" --raw`, names targets by selector, and
   takes the states first, then the transitions as one video:

   ```bash
   # a state: the element that holds it, so the cards stay out of frame
   playwright-cli -s=qa-<pr> screenshot "<selector>" --hires --filename <dir>/<n>-<state>.png
   # a state that needs the whole viewport
   playwright-cli -s=qa-<pr> eval "() => __qa.hide()" --raw
   playwright-cli -s=qa-<pr> screenshot --hires --filename <dir>/<n>-<state>.png
   playwright-cli -s=qa-<pr> eval "() => __qa.show()" --raw
   # the transitions
   playwright-cli -s=qa-<pr> video-start <dir>/qa.webm --size 2560x1800 --fps 30
   playwright-cli -s=qa-<pr> run-code "async page => { await page.screencast.showActions({ cursor: 'none', duration: 800, position: 'top-right', style: {
     title: 'font: 600 13px/1.3 -apple-system, sans-serif; padding: 6px 10px; border-radius: 8px; background: rgba(17,18,24,.93); color: #fff; border: 1px solid rgba(255,255,255,.14)',
     highlight: 'outline: 2px solid #818cf8; outline-offset: 2px; border-radius: 6px; background: rgba(129,140,248,.12)' } }); }"
   playwright-cli -s=qa-<pr> eval "() => __qa.cases(<number of chapters>)" --raw
   # per case
   playwright-cli -s=qa-<pr> eval "() => __qa.chapter('<n>. <case>', '<expected>')" --raw
   playwright-cli -s=qa-<pr> eval "() => __qa.step('ケース <n>: <case>', '<what is done>\\n期待: <expected>')" --raw
   playwright-cli -s=qa-<pr> eval "() => __qa.plan('<label>', '<label>')" --raw
   # ...the rehearsed actions: scrolls eased, the pointer sent ahead of each click...
   playwright-cli -s=qa-<pr> eval "() => __qa.scroll('<selector>')" --raw
   playwright-cli -s=qa-<pr> eval "() => __qa.point('<selector>')" --raw
   playwright-cli -s=qa-<pr> click "<selector>"
   playwright-cli -s=qa-<pr> eval "() => { const s = <read the DOM>; return [__qa.check('<label>', s.rows, 20), __qa.check('<label>', s.more, true)]; }" --raw
   # after the last case
   playwright-cli -s=qa-<pr> eval "() => __qa.finish()" --raw
   playwright-cli -s=qa-<pr> video-stop
   playwright-cli -s=qa-<pr> close
   ```

   A screenshot is the element that holds the state — the app frame, the
   banner — and `--hires` saves device pixels, so it lands at Retina
   density. The pointer is the overlay's own, since Playwright's cannot be
   sized: `video-start` takes no `--cursor`, and `showActions` goes through
   `run-code` with `cursor: 'none'`, which the CLI's flag cannot say. The
   action callout and the target highlight are Playwright's, styled to the
   cards' palette. A case whose observable is motion itself (a drag, an
   animation) is worth `--fps 60`. `window.__qa` (`scripts/qa-overlay.js`)
   draws in the top layer, above the app's own dialogs, where the page
   cannot see it — inert, aria-hidden, closed shadow root, absent from
   snapshots — and survives navigations:

   - `clear()` — resets everything; run it first. `cases(total)` — how many
     chapters the video has: each chapter fills one segment of the progress
     bar on the caption and chapter cards, and the current segment fills at
     a constant speed — the previous case's pace — until the case's last
     planned check closes it.
   - `chapter(title, detail, hold)` — a centered chapter card, with a ring
     around the number that closes as the hold runs out; resolves after the
     card has faded. A leading `<n>.` is shown as the number. It starts the
     case: the checklist and the console are emptied.
   - `step(title, detail, hold)` — caption card, as wide as its text; a
     leading `ケース <n>:` is shown as a badge, and a `\n` in `detail` puts the
     expectation on its own line. Resolves after `hold` ms so the viewer
     reads it before the action; left out, `hold` grows with the text (about
     nine characters a second, 1.2 to 4 s; a chapter 1.5 to 3.5 s), so short
     captions keep the video short.
   - `point(selector)` — glides the pointer to the element's centre and
     resolves on arrival; a click without it lands before the pointer does.
     A CSS selector, quoted for the shell: `[href=\"#id\"]`. Mouse-down dips
     the pointer and spreads two rings on its own.
   - `scroll(to)` — eases the page to `'top'`, `'bottom'`, a y offset or a
     selector, where `scrollTo` or a wheel command would cut to the new
     position. Any scroll, the app's own jumps included, shows a rail on the
     right edge with the position and the direction.
   - `plan(label, …)` — lists the case's checks in the checklist card, on
     the right, before they run, so the viewer sees what will be verified.
     `check(label, actual, expected)` — ticks the row with that label and
     writes what was read beside it, green, or red with `(expected …)`; a
     label `plan` did not list gets a row of its own. Returns `{ pass,
     actual }`; `expected` is a value, a predicate, or absent for a truthy
     check.
   - The console is the page's own output — `console.log/info/warn/error`,
     uncaught errors, and `log(text)` — under the checklist, and hidden
     unless a case needs it: `console('open')` keeps a tall one on screen
     for a case whose observable is what the console says, `console('auto')`
     shows a small one while it has lines.
   - Keys show as keycaps on top of the caption card on their own — from
     `type` and `press`, not `fill`, which sets the value without key
     events; a password field shows dots.
   - `device(width, height, label)`, `frame()` — the device stage of step 3.
   - `finish()` — the closing card: the tally of every check since
     `clear()`, with confetti when none failed. Run it once, last.
   - `place("top")` when the cards would hide the element under test;
     `hide()` / `show()` take the overlay out of frame and back. The cards
     turn light on a dark page.
5. Convert and look. Read every PNG. For the video:

   ```bash
   ffmpeg -i qa.webm -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart qa.mp4
   ffmpeg -i qa.mp4 -vf "fps=1/3,scale=640:-1,tile=4x4" sheet-%02d.png
   ```

   Read every `sheet-*.png`. Done when every screenshot shows its state
   whole, every chapter card, caption and check line is legible with
   nothing clipped, and the cursor and ripple land on the controls being
   used. Keep `-crf 20` whatever the size, up to GitHub's 100 MB: the
   user's work account takes it, and sharp text is the point. Only when
   the upload in step 6 is refused for size (a free plan stops at 10 MB)
   re-encode with `-crf 28`, about half the size, before cutting cases.

   With `--video-only`, go to step 7 from here and report the absolute
   path of `qa.mp4`.

6. Place. The PR decides where: the user's own PR carries the report in
   its body; a PR the user reviews (`--review`, or an `author.login` other
   than the viewer) carries it in the user's pending review, where the
   reviewer's evidence and verdict are read together and the author's
   body stays theirs. Either way the report reads as the user's own test
   record, vetted before it is placed: no `[from Claude Code]` marker and
   no line naming who ran it.

   In the body: take the current one (`gh pr view <url> --json body --jq .body`)
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
     for review. The screenshots keep their `<details>` under
     `## Screenshot(s)`.
   - Otherwise the `## Manual QA` section below: replaced if an earlier
     run left one, appended after the author's text if not.

   Evidence is written as markdown references to the local files —
   `![<n> <state>](./<n>-<state>.png)`, and `![](./qa.mp4)` alone in its
   paragraph — and `gh pr edit` (≥ 2.99) rewrites each to its uploaded
   asset in place: an image keeps its alt, the video becomes the bare URL
   GitHub renders as a player. Paths in the body are relative to the body
   file. Show the draft, the images and the sheet, and wait for the user's
   yes: `allowed-tools` lets `gh` and `bash` run without a prompt, so
   nothing else stops the upload. On the yes, or with `--post`, run from
   that directory:

   ```bash
   gh pr edit <url> --body-file qa-body.md --attach ./<n>-<state>.png --attach ./qa.mp4
   ```

   Every QA screenshot keeps its captured resolution but shows at most
   600 CSS pixels high, aspect ratio kept, and links to the original. For
   an image of W×H pixels the display width is
   `floor(min(W, 600 * W / H))`; side-by-side variants also cap it at 180.
   A 772×1800 compact screenshot becomes 257 pixels wide and about 599
   high. That takes HTML gh does not rewrite: after the upload, read the
   body back, turn each image into
   `<a href="<asset url>"><img width="<display width>" alt="<n> <state>" src="<asset url>" /></a>`
   — `width` only — in a second `gh pr edit --body-file`, then check the
   widths and the full-size links in the body. Variants stay on one row
   under their numbered captions.

   In the review: write the `## Manual QA` section below as `qa-body.md`
   in the directory that holds the files, with the same references, except
   that every screenshot is written sized straight away, by the rule above
   with the local path in both places —
   `<a href="./<n>-<state>.png"><img width="<display width>" alt="<n> <state>" src="./<n>-<state>.png" /></a>`
   — since no second edit follows the upload. Show the draft, the images
   and the sheet, and wait for the user's yes as for the body. On the yes,
   or with `--post`, run from that directory:

   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/place-qa-review.sh" <url> qa-body.md ./<n>-<state>.png ./qa.mp4
   ```

   `gh pr review` has no `--attach`, so the script uploads the files to
   the repository itself (push access is required), rewrites each
   `(./file)` and each quoted `"./file"` — the `src` and `href` above,
   which `gh pr edit` would leave alone — to its asset URL, and writes the
   section into the user's pending review: the one
   `posting-pr-review` left, its earlier `## Manual QA` replaced, or a
   new one. The review stays pending; the user reads it on GitHub and
   submits it with their verdict.

7. Clean up — the session (`close`), the local server, the worktree — and
   report in Japanese: the PR URL, the cases, what was not covered, and,
   for a review, that it stays pending until the user submits it.

## Section format

The premise and what was not checked are folded, so the cases and the
evidence are what the reviewer sees first; the blank lines inside each
`<details>` are what make its Markdown render. Screenshots are folded too
— they are tall, and the summary says how many and for which cases — while
the video stays open. A heading whose kind of
evidence the run has none of is left out. A screenshot on its own gets its
caption line, then the image; variants side by side get one `<ol>` above
the row, a `<li value="<n>">` per image, because Markdown renumbers
`1. 2. 4.` to 1, 2, 3 and the number is the case's. One sentence per line
in prose: a PR body renders the newline as a line break.

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

<details>
<summary>スクリーンショット <count> 枚（ケース <n>, <n>, <n>）</summary>

<n>. <state>（<caption>）

![<n> <state>](./<n>-<state>.png)

<ol>
<li value="<n>"><state>（<caption>）</li>
<li value="<n>"><state>（<caption>）</li>
</ol>

![<n> <state>](./<n>-<state>.png) ![<n> <state>](./<n>-<state>.png)

</details>

### 録画

動画の区切りカードの番号は上の表の # に対応します。
左下の字幕が操作と期待、右下のチェックリストが確認結果です。

![](./qa.mp4)
```
