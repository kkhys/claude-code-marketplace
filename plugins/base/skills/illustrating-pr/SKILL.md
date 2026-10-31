---
name: illustrating-pr
description: Draw a pull request as one eli15 picture for an engineer reader and place it in the PR description (or a comment) with gh --attach
argument-hint: "[PR number | PR URL] [--comment]"
disable-model-invocation: true
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Illustrating a PR

Explain this PR like I'm 15, to an engineer who knows the stack and nothing
about this change: one big picture, very few words, in Japanese.

## PR context

- Argument: $ARGUMENTS
- Current branch's PR: !`gh pr view --json number,title,url,headRefOid,baseRefName,changedFiles,additions,deletions 2>/dev/null || echo "none"`

An argument naming a PR wins over the current branch; fetch the same fields
for it. `--comment` in the argument selects a comment over the description
in step 4.

## Steps

1. Read the change: `gh pr view <pr> --json title,body,files,commits`,
   `gh pr diff <pr>`, then the touched files — the working tree when the
   branch is checked out, otherwise `git fetch` and
   `git show <headRefOid>:<path>`. Done when you can say what behaviour
   changes, why, and the one thing a reviewer could miss. A diff that reads
   in a minute (typo, bump, rename) gets no picture: say so and stop.

2. Draw. Write a self-contained HTML page — inline CSS and SVG, system
   fonts, nothing fetched — in the scratchpad. The canvas is yours to size;
   GitHub shows a PR image about 900 px wide, so on a 1600 px canvas body
   text is 30 px or larger.

3. Render it with the local Chrome at device scale 2, `--window-size`
   matching the canvas:

   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
     --window-size=1600,900 --force-device-scale-factor=2 \
     --screenshot=<dir>/panel.png file://<dir>/panel.html
   ```

   Then Read the PNG. Done when nothing is clipped, labels sit clear of
   lines and of each other, and the claim reads from the picture before the
   words.

4. Place. Write the section below as a file, then run gh (≥ 2.99) from the
   image directory, naming the PR by URL: gh uploads each `./file` the body
   references and rewrites the reference to the asset URL.

   - Description (default): take the current body from
     `gh pr view <url> --json body --jq .body`; replace its `## In pictures`
     section if an earlier run left one, otherwise append the section after
     the author's text; change nothing else; then
     `gh pr edit <url> --body-file <full body> --attach ./panel.png`.
   - `--comment`: `gh pr comment <url> --body-file <section> --attach ./panel.png`,
     without the heading.

   The text is posted as written, with no `[from Claude Code]` marker.

5. Report in Japanese: the URL where the picture landed and its headline.

## Section format

```markdown
## In pictures

![<headline>](./panel.png)
```

Nothing else: the picture says it all.
