# Editorial diagram

The second kind of picture, for a PR whose mechanism is a structure rather
than something an everyday object behaves like: components and the edges
between them, a sequence of calls across parties, a state machine, a
pipeline. A scene would have to invent a metaphor the reader then has to
undo; the diagram shows the structure itself. The register still holds —
the reader's words on the nodes, identifiers in `.mono` under them — only
the drawing grammar changes.

The grammar is borrowed from cathrynlavery/diagram-design (MIT): editorial
diagrams built from deletion, one accent, hairlines, and a 4 px grid. When
that skill is installed (`~/.agents/skills/diagram-design` or
`~/.claude/skills/diagram-design`), its `references/type-<kind>.md` gives
the layout of each kind in detail; read it for the layout, then draw with
this skill's skeleton so the panel keeps its theme, size, and offline render.

## When it is the right picture

| The reader must see | Kind |
|---|---|
| Which pieces talk to which, and the one edge this PR adds or removes | Architecture delta: before and after side by side, same positions, a short ledger of what changed |
| Who calls whom in what order, and where the new step sits | Sequence: one column per party, time runs down, every arrow labelled |
| Which states exist and what moves between them | State machine: rounded states, transitions labelled with the guard |
| A stream of records through stages, and which stage changed | Data flow: stages left to right, the record drawn once at each stage it changes shape |

Reach for a scene instead when the mechanism has an everyday double —
a bookmark, a door, a queue at a counter — because the double carries the
intuition and the diagram would only carry the topology. Reach for a table
or the `.box` grid when the change is attribute-only (a flag, a default, a
limit); a diagram of unchanged topology says nothing.

## Rules

- The highest-quality move is deletion. Two nodes that always travel
  together are one node. An edge the layout already implies is not drawn.
  The diagram is done when nothing can be removed, not when everything is
  in.
- At most nine nodes; past that, it is two panels. Target density is
  "complete but needs no guide".
- One accent, one or two focal nodes. In a PR panel the accent is `.new`
  on what this PR adds or changes, `.old` dashed on what it removes;
  everything else is ink and `.muted`. A diagram with five green nodes has
  no focus.
- Every edge carries a label: what moves, or what triggers it. An
  unlabelled arrow is "related somehow".
- Nodes are `.paper` rectangles with 8 px radius and the 3 px ink stroke;
  a boundary (a service, a process, a host) is a `.soft` or dashed `.ink`
  rectangle around its nodes with a `.small muted` name in its top-left.
- Node names in the reader's words, 26 px; the identifier — a class, a
  path, a port, a command — in `.mono`, 24 px, one line, under the name.
- Every coordinate, width, and gap is a multiple of 4; rows of nodes share
  a baseline; columns share an x. Eyeballed offsets read as noise.
- Before/after keeps the same node positions in both halves so the eye
  finds the difference by flicking, and the ledger beside them names each
  difference in one line.

## Example: sequence with the new step

```html
<h1>保存は一度キューに積んでから書く<small>画面は即座に戻り、書き込みは裏で順に流れる</small></h1>
<svg class="scene fill" viewBox="0 0 1472 560" role="img" aria-label="画面、キュー、ワーカー、DB の四列。画面がキューに積んで即座に戻り、ワーカーが順に取り出して DB に書く。失敗したら積み直す">
  <!-- parties -->
  <g>
    <rect x="40" y="16" width="200" height="80" rx="8" class="paper"/><text x="140" y="64" text-anchor="middle" class="small">画面</text>
    <rect x="440" y="16" width="200" height="80" rx="8" class="paper new"/><text x="540" y="48" text-anchor="middle" class="small">キュー</text><text x="540" y="80" text-anchor="middle" class="mono">SaveQueue</text>
    <rect x="840" y="16" width="200" height="80" rx="8" class="paper new"/><text x="940" y="48" text-anchor="middle" class="small">ワーカー</text><text x="940" y="80" text-anchor="middle" class="mono">SaveWorker</text>
    <rect x="1240" y="16" width="200" height="80" rx="8" class="paper"/><text x="1340" y="64" text-anchor="middle" class="small">DB</text>
    <path class="ink thin dash" d="M140 96 V520 M540 96 V520 M940 96 V520 M1340 96 V520"/>
  </g>
  <!-- messages, time runs down -->
  <g class="new">
    <path class="ink" d="M140 152 H536" marker-end="url(#ah)"/><text x="340" y="140" text-anchor="middle" class="mono">push(doc)</text>
    <path class="ink" d="M536 200 H144" marker-end="url(#ah)"/><text x="340" y="188" text-anchor="middle" class="small">すぐ返事</text>
    <path class="ink" d="M540 264 H936" marker-end="url(#ah)"/><text x="740" y="252" text-anchor="middle" class="small">1 件ずつ取り出す</text>
  </g>
  <path class="ink" d="M940 328 H1336" marker-end="url(#ah)"/><text x="1140" y="316" text-anchor="middle" class="mono">repo.write(doc)</text>
  <path class="ink" d="M1336 376 H944" marker-end="url(#ah)"/><text x="1140" y="364" text-anchor="middle" class="small">書けた / 失敗</text>
  <g class="new">
    <path class="ink dash" d="M940 440 H544" marker-end="url(#ah)"/><text x="740" y="428" text-anchor="middle" class="small">失敗なら積み直す（3 回まで）</text>
  </g>
  <text x="40" y="548" class="small muted">緑がこの PR で増えた列と手順。画面は 2 手目で手が空く</text>
</svg>
```
