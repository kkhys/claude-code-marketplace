---
name: illustrating-pr
description: Draw a pull request as two to four eli15 picture panels for an engineer reader, rendered to PNG and placed in the PR description (or a comment) with gh --attach. Only on explicit request.
argument-hint: "[PR number | PR URL] [--comment]"
disable-model-invocation: true
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Illustrating a PR

An agent-written PR reaches its reviewer as a diff nobody watched being
made. The pictures give back the overview the author had: what changes,
where it sits, how the main path runs now, what could be missed. Each
picture is one 1600×900 panel written as an HTML fragment, rendered to PNG by
the bundled script, and all of them land in one place on the PR, so the
reviewer reads them top to bottom before opening the diff.

## The register

The reader is an engineer who knows git, GitHub, and the stack, and nothing
about this change. eli15 is how the picture explains, not how the words
sound: one claim per panel, an everyday object that behaves like the
mechanism, nobody needing the diff to parse it. The words are the reader's
own — develop, push, merge, CI, PR, the function's name — and plain words are
spent on what is specific to this PR: what this code does, what changed, what
it costs. A panel is built in this order:

1. A headline in plain words that states the claim or asks the question —
   「コンフリクトした PR を、どこで直すか」, never 「変更点」, never a
   sentence that needs the diff to parse.
2. One big picture. By default a scene: actors and an everyday object that
   behaves like the mechanism — a trunk line and a branch that rejoins it,
   a door that only opens one way, a bookmark in a scroll, a letter handed
   over. Boxes with arrows are a diagram, which is what the reader could
   have drawn from the diff; a scene is what they could not. Someone is in
   the picture: あなた, the AI, GitHub as a cloud.
3. Two sentences at most beside or under the picture, in the same words.
   The panel ends there: the picture and its sentences carry everything,
   and the identifiers the reader will meet in the diff — a command, a
   path, a function — sit inside the picture where they act, as `.mono`
   text beside the shape, a `.box` label, or a step.

Plain is not childish, and the reader's words are not jargon. The voice is
a careful colleague at a whiteboard: 変更前 / 変更後, 誤って触れる, あなた
の確認を得る — kanji where an adult would write them, roles named as at work
(担当), and quoted speech only when it is literally what the screen says.
The metaphor carries the eli15 part; a term the reader uses daily stays as
it is, because a plainer stand-in (枝 for ブランチ, 押し出す for push) makes
an engineer translate back.

A panel that opens with an identifier, or whose picture is identifiers in
boxes, has the order backwards.

When the mechanism is a structure — which pieces talk to which, who calls
whom in what order, which states exist — no everyday object carries it, and
the picture is an editorial diagram instead: `references/editorial-diagram.md`.
It is the exception, not the default; a scene wins whenever the mechanism
has an everyday double, and a table or the `.box` grid wins for an
attribute-only change.

## PR context

- Argument: $ARGUMENTS
- Current branch's PR: !`gh pr view --json number,title,url,headRefOid,baseRefName,changedFiles,additions,deletions 2>/dev/null || echo "none"`

An argument naming a PR wins over the current branch; fetch the same fields
for it. `--comment` in the argument selects a comment over the description
in step 5.

## Process

1. Read the change. `gh pr view <pr> --json title,body,files,commits`,
   `gh pr diff <pr>`, then the touched files themselves — the working tree
   when the branch is checked out, otherwise `git fetch` and
   `git show <headRefOid>:<path>`. Done when you can state, in one sentence
   each: what behaviour changes, why, which pieces of the system it touches,
   what the main path does now, and the one thing a reviewer could miss. A
   scene asserts a mechanism, so read the code before drawing it; a wrong
   picture costs more than a missing one. A diff that reads in a minute
   (typo, bump, rename) gets no picture: say so and stop.

2. Pick the panels, two to four, in this order:

   | Panel | The question it answers | Draw when |
   |---|---|---|
   | 変更前後 | 何が、どう変わるのか — the same actors before and after, stacked | Always, first |
   | 地図 | どこが変わったのか — the touched pieces among their neighbours, changed green, removed red, untouched gray | Three or more files, or a new module |
   | 流れ | 動くとどうなるのか — the main path step by step, new steps green, with a scene beside the steps | The order or logic of a path changed |
   | 注目点 | どこに気をつけるのか — the one decision or edge case the diff hides | There is one — a boundary, a fallback, a migration, a changed default |

   Each panel answers one question, and its `h1` is the answer in plain
   words. Before drawing, name the everyday object each panel's mechanism
   behaves like; a panel without one is either an editorial diagram (a
   structure) or a labelled diagram (a mistake).

3. Write one fragment per panel into
   `<scratchpad>/illustrating-pr/pr-<number>/NN-<slug>.html` — the inside of
   the canvas only, composed from the scene stamps and blocks in
   `references/panel-design.md`. Text in Japanese, unless the user asks
   otherwise or the PR's reviewers evidently work in English; an English
   PR body alone does not decide it.

4. Render (`${CLAUDE_SKILL_DIR}` is this skill's directory; when the variable
   reaches you unexpanded, use the directory that holds this SKILL.md):

   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/render-panels.sh" <dir> <dir>/*.html
   ```

   Every panel renders twice — `NN-slug.png` for GitHub's light theme and
   `NN-slug.dark.png` for dark. The run goes red on a panel that spills past
   the canvas or draws outside a scene's viewBox, naming the text; cut
   words, move the label, or split the panel rather than shrinking type.
   Then Read every light PNG and one dark one. Done when each is clean:
   nothing clipped, no stamp drawn solid, labels clear of lines and of each
   other, and the claim readable from the picture before the sentences.

5. Place. Write `<dir>/body.md` in the format below, then:

   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/attach-explainer.sh" <pr> <dir>/body.md <dir>/*.png
   ```

   By default the panels go into the PR description, as a fenced section
   after the author's bullets; a rerun after a further push replaces that
   section and nothing else, so the description always shows the pictures
   for its head commit. `--comment` posts one comment instead — for a PR
   the user cannot edit, or when the user wants a dated record of each
   round. Either way the script checks every image against gh's limits,
   prefixes the attribution marker, and runs gh from the image directory so
   each `./file` reference resolves; write the body without the marker and
   reference only the light files — each `.dark.png` is paired with its
   twin and, in a second step, folded into a `<picture>` that follows the
   viewer's GitHub theme.

6. Report in Japanese: where the pictures landed (the PR URL), one line per
   panel, and the head SHA the pictures describe.

## Section format

```markdown
`<short head sha>` 時点の差分を図にしました。

### 1. <panel headline>
![<panel headline>](./01-<slug>.png)
<one sentence in the panel's words: what to take from the picture>

### 2. <panel headline>
![<panel headline>](./02-<slug>.png)
<one sentence>
```

- In the description the script puts `## In pictures` above all of this,
  an English heading like the PR's title and bullets; a comment gets no
  heading. Write neither.
- The first line names the head commit, so a later push cannot pass the
  pictures off as current.
- One `###` per panel, numbered in reading order; the heading is the panel's
  `h1`, the alt text repeats it, and the image is referenced as `./<file>`,
  which gh rewrites to the uploaded asset.
- One sentence under each image, nothing else: no note on how the pictures
  were made, no restated diff, and no section markers — the script adds
  those.
