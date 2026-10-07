# Panel design

How a panel is drawn. The skeleton in `assets/panel.html` fixes the canvas,
the type, the colours, a set of scene stamps, and a few HTML blocks; a
fragment composes them and adds a `<style>` only for a layout they do not
cover.

## The canvas

| Fact | Value |
|---|---|
| Canvas | 1600 × 900 CSS px, 56 px top/bottom and 64 px side padding |
| PNG | 3200 × 1800 (device scale 2) |
| Shown on GitHub | about 55 % — roughly 880 px wide in the PR timeline |
| Body text | 30 px, which reads as 16 px on GitHub |
| Smallest text | 22 px (`.small`, `.box .label`); anything smaller is unreadable without a click |

The canvas is a flex column with a 32 px gap: `h1`, then the picture, and
the panel ends with the picture. Give the picture `.fill` so it takes the
remaining height — about 640 px under a one-line headline with its
expansion, 580 px under a two-line one.

Everything renders offline from a `file://` URL. Fonts come from the system
(Hiragino / Noto Sans JP, SF Mono / Menlo); a web font, an image URL, or a
script in a fragment renders as nothing.

## Scenes

A scene is an inline `<svg class="scene fill" viewBox="0 0 1472 560">` —
1472 is the canvas width inside the padding, and 560 fits under a two-line
headline. Keep 560: the svg takes whatever height is left and draws the
viewBox at scale 1 inside it, so a taller viewBox is scaled down with
margins either side, and a shorter one only leaves room. Draw with native
shapes and the stamps, in `currentColor`, so one fragment renders in both
themes.

Text width is the budget that bites: a 22 px `.small` label needs 22 px per
CJK character and 12 px per Latin one, a 26 px label 26 and 14, a 24 px
`.mono` command 15 per character. A centred label (`text-anchor="middle"`)
spreads half its width to each side, so one near the left edge spills past
x = 0. The render script reports any text, stamp, or shape outside the
viewBox as OVERFLOW, naming the text; move it, shorten it, or left-align it.

| Stamp | Draws | Typical size |
|---|---|---|
| `#person` | あなた, a reviewer | 90–110 |
| `#robot` | the AI, an agent | 90–110 |
| `#cloud` | GitHub, a remote, anything "over there" | 120 × 80 |
| `#doc` | a file, a PR, a letter | 70–90 |
| `#wrench` | fixing, a change applied here | 56–64 |
| `#check` | a passed check, done | 56–64 |
| `#button` | a button someone presses | 90–100 |
| `#bubble` | speech; put the `<text>` on top yourself, up to six characters | 160 × 90 |

```html
<use href="#person" x="700" y="160" width="110" height="110"/>
<use href="#bubble" x="630" y="60" width="160" height="90"/>
<text x="710" y="108" text-anchor="middle" class="small">push する？</text>
```

A stamp keeps its ratio inside the box it is given, so a wider `#bubble`
or `#cloud` needs a taller one too; otherwise it is drawn at the height's
scale and centred in the box.

Drawing classes, all following `currentColor`:

| Class | Use |
|---|---|
| `.ink` | a line or an outline; `.thick` for a trunk, `.thin` for a guide, `.dash` for "not yet" |
| `.paper` | a filled shape on the page colour — doors, cards, bubbles |
| `.soft` | a filled shape on the surface colour, hairline border — a resting object |
| `.tint` | a shape tinted with the current colour at 12 % — the thing this panel is about |
| `.dot` | a solid mark |
| `.small`, `.big`, `.mono`, `.muted` | text sizes and roles; `.mono` is for a command, a path, a name from the code |
| `marker-end="url(#ah)"` | an arrowhead; `marker-start` as well for two-way |

Colour the actors, not the decoration: wrap a group in `<g class="new">`,
`old`, `focus`, `warn`, or `muted` and everything inside takes that colour —
stamps included. One group per meaning; the rest stays in the text colour.

## Blocks

For a 流れ panel the steps sit in HTML beside a scene; for a 地図 panel the
pieces are boxes in a grid. The blocks:

| Block | Use |
|---|---|
| `<h1>headline<small>one-line expansion</small></h1>` | The panel's claim in plain words. One per panel |
| `.row`, `.col`, `.grow`, `.fill`, `.center`, `.grid-2`, `.grid-3` | Layout. `.row` centres items vertically with a 28 px gap |
| `.box` + `.new` / `.old` / `.dim` / `.focus` / `.warn` | A piece of the system in a 地図; `.box .label` for its role |
| `.arrow` + `.new` / `.old` / `.down` / `.back` | An edge between boxes; the element's text is the label |
| `ol.steps` with `li` / `li.new` | An ordered path, at most seven steps |
| `.badge` + colours | A row label: 変更前, 変更後 |
| `.note` / `.note.warn` | The one sentence the picture cannot carry |
| `<code>` | An identifier inside a box, a step, or a note; in a scene, `.mono` text |

Colour carries one meaning each, so the reader learns it on the first panel:

| Colour | Token | Meaning |
|---|---|---|
| green (`.new`) | `--c-new` (uchu green) | added or changed by this PR, 変更後 |
| red (`.old`) | `--c-danger` | removed, 変更前, where things collide |
| blue (`.focus`) | `--c-link` | the thing to look at on this panel — あなたのブランチ |
| orange (`.warn`) | `--c-warn` (uchu orange) | a caution the reviewer should carry |
| gray (`.muted`, `.dim`) | `--c-sub` / `--c-surface` | untouched context |

Nothing else is coloured. The skeleton mirrors the design system at
design.kkhys.me — uchu OKLCH palette, `--c-*` semantics through
`light-dark()`, hairlines instead of cards, system-ui at 400/600 — so a panel
sits next to the user's own sites without looking imported. Every token has
a light and a dark value and the render script produces both themes from
one fragment, so a fragment names colours only through these classes: a
literal hex value in a `style` attribute renders in one theme and breaks the
other. Inline `style` is for layout — `justify-content`, `gap`, `width`.

## Layout rules

- One claim per panel. A second claim is a second panel.
- The reader's words in the picture — develop, push, CI, the function's
  name — and plain words for what is specific to this PR. A thing this PR
  introduces that has no name the reader knows is drawn by what it does and
  labelled in plain words, its real name in `.mono` beside it.
- Before/after as two stacked rows, actors in the same order, so the eye
  compares column by column.
- At most six `.box` per row and two rows of boxes; past that, split.
- Boxes keep their width (`flex-shrink: 0`): a row that is too long trips the
  overflow probe instead of squeezing a name into a column of characters.
  Fix an overflow by cutting words, dropping a box, or splitting the panel;
  the type sizes stay.
- Labels in a scene sit clear of lines and of each other; after rendering,
  Read the PNG and move any that touch.
- Left to right is time or causality; top to bottom is before to after, or
  layers from caller to callee.

## Example: 変更前後 as a scene

```html
<h1>コンフリクトした PR を、どこで直すか<small>develop 宛てだけ develop の上で直して push する。マージボタンは押さない</small></h1>
<svg class="scene fill" viewBox="0 0 1472 560" role="img" aria-label="変更前は作業ブランチの上で直してマージボタンで取り込む。変更後、develop 宛てなら develop の上で直し、push した時点でマージされる">
  <text x="0" y="28" class="small muted">変更前。main など develop 以外に宛てた PR は、変更後も同じ</text>
  <text x="0" y="214" class="small muted">マージ先</text>
  <path class="ink thick" d="M40 180 H880"/>
  <text x="220" y="78" class="small muted">あなたのブランチ</text>
  <g class="focus"><path class="ink thick" d="M180 180 C240 180 240 100 300 100 H560 C620 100 620 180 680 180"/></g>
  <g class="old">
    <use href="#wrench" x="404" y="52" width="64" height="64"/>
    <text x="436" y="150" text-anchor="middle" class="small">ブランチの上で直す</text>
    <circle cx="680" cy="180" r="20" class="paper"/><text x="680" y="190" text-anchor="middle" class="big">!</text>
    <text x="680" y="236" text-anchor="middle" class="small">コンフリクト</text>
  </g>
  <path class="ink" d="M880 180 H936" marker-end="url(#ah)"/>
  <use href="#button" x="950" y="130" width="100" height="100"/>
  <text x="1000" y="262" text-anchor="middle" class="small">マージボタン</text>
  <path class="ink" d="M1060 180 H1116" marker-end="url(#ah)"/>
  <use href="#cloud" x="1130" y="130" width="140" height="100"/>
  <text x="1200" y="262" text-anchor="middle" class="small">merged</text>

  <g class="new"><text x="0" y="318" class="small">変更後。develop 宛ての PR</text></g>
  <text x="0" y="504" class="small muted">develop</text>
  <path class="ink thick" d="M40 470 H880"/>
  <text x="300" y="368" class="small muted">あなたのブランチ</text>
  <g class="focus"><path class="ink thick" d="M180 470 C240 470 240 390 300 390 H560 C620 390 620 470 680 470"/></g>
  <g class="old"><circle cx="680" cy="470" r="20" class="paper"/><text x="680" y="480" text-anchor="middle" class="big">!</text></g>
  <g class="new">
    <use href="#wrench" x="748" y="394" width="64" height="64"/>
    <text x="780" y="526" text-anchor="middle" class="small">develop の上で直す</text>
    <path class="ink thick" d="M880 470 H1116" marker-end="url(#ah)"/>
    <text x="998" y="446" text-anchor="middle" class="small">push</text>
    <use href="#cloud" x="1130" y="420" width="140" height="100"/>
    <text x="1200" y="548" text-anchor="middle" class="small">push した時点で merged</text>
  </g>
  <text x="998" y="512" text-anchor="middle" class="small muted">ボタンは押さない</text>
</svg>
```

## Example: 流れ with steps beside a scene

```html
<h1>develop の上で直すときの、五つの手<small>コンフリクトを直すのは一度だけ。直した人がその場でチェックも回す</small></h1>
<div class="row fill" style="gap: 56px; align-items: stretch;">
  <ol class="steps grow" style="justify-content: center;">
    <li>develop を最新にする</li>
    <li class="new">あなたのブランチを develop に <code>git merge --no-ff</code>。ここでコンフリクト</li>
    <li>両方の意図を残して直し、プロジェクトのチェックを回す</li>
    <li class="new">マージコミットとチェック結果を見せて、あなたの確認を得る</li>
    <li class="new"><code>git push origin develop</code>。GitHub が PR を merged にする</li>
  </ol>
  <svg class="scene" viewBox="0 0 520 560" style="width: 520px; flex: none;" role="img" aria-label="ブランチが develop に取り込まれ、develop の上で直し、あなたが確認してから push する">
    <text x="20" y="40" class="small muted">作業ブランチ</text>
    <g class="focus"><path class="ink thick" d="M40 60 V120 C40 180 160 180 160 240"/></g>
    <text x="200" y="40" class="small muted">develop</text>
    <path class="ink thick" d="M160 60 V500"/>
    <g class="old"><circle cx="160" cy="240" r="18" class="paper"/><text x="160" y="249" text-anchor="middle" class="big">!</text></g>
    <g class="new"><use href="#wrench" x="196" y="262" width="60" height="60"/><text x="270" y="300" class="small">ここで直す</text></g>
    <use href="#person" x="300" y="340" width="90" height="90"/>
    <use href="#bubble" x="380" y="310" width="130" height="74"/>
    <text x="445" y="352" text-anchor="middle" class="small">はい</text>
    <g class="new"><path class="ink thick" d="M160 500 H400" marker-end="url(#ah)"/><text x="280" y="480" text-anchor="middle" class="small">push</text></g>
    <use href="#cloud" x="400" y="450" width="110" height="80"/>
    <text x="455" y="556" text-anchor="middle" class="small muted">merged</text>
  </svg>
</div>
```

## Example: 地図 with boxes

```html
<h1>変わったのは、誰が編集できるかを決める一枚だけ<small>画面と DB には触れていない</small></h1>
<div class="grid-3 fill" style="align-content: center;">
  <div class="box dim"><span class="label">画面</span>設定ページ</div>
  <div class="box new"><span class="label">認可</span><code>canEdit</code> — 持ち主か、共同編集者なら通す</div>
  <div class="box dim"><span class="label">DB</span><code>documents</code></div>
  <div class="box dim"><span class="label">画面</span>一覧ページ</div>
  <div class="box old"><span class="label">認可</span><code>isOwner</code> — 持ち主だけ通す。削除</div>
  <div class="box dim"><span class="label">DB</span><code>collaborators</code></div>
</div>
```
