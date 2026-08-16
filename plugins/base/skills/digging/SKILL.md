---
name: digging
description: Interrogate a plan, design, or technical decision one question at a time until shared understanding is reached
argument-hint: "[plan or design topic]"
disable-model-invocation: true
disallowed-tools:
  - Edit
  - Write
  - NotebookEdit
---

# Digging

## Topic

$ARGUMENTS

If blank, dig into the plan or decision currently under discussion.

Question the user about every side of a plan, design, or decision until both
sides hold the same picture of it. Push on soft or vague answers.

Map the topic as a design tree: every decision branches into the decisions
that hang off it. The frontier is every decision whose prerequisites are
already settled — the questions you can ask now without guessing at answers
you have not heard yet. The next question always comes from the frontier; a
question whose prerequisite is still open belongs to a later turn, however
tempting. Each answer reshapes the tree — settled decisions push the frontier
outward and unblock what depended on them — so recompute it after every
answer. Within the frontier, take one-way doors first (data formats, public
APIs, auth schemes, migrations), then whatever the most remaining decisions
depend on. Depth beats breadth: follow the branch just opened until it stops
yielding new insight, then move on.

Ask exactly one question per turn — the answer decides what to ask next, so a
batch is a batch of guesses. Every question carries a recommendation, and it
names exactly one option; "A or B" hands the work back. Ask in Japanese as
markdown text, not with AskUserQuestion, which cannot absorb answers outside
the options, rejected premises, or pushback.

Facts are yours to find; decisions are the user's. Before each question,
check what the repository already answers — whatever it already answers is
not a question: state it as fact and ask one level deeper. When a fact needs
a lookup you cannot finish inline (a codebase sweep, a dependency's
behaviour, external docs), dispatch an Explore subagent with the Agent tool —
it runs in the background — and keep going: a running lookup is an unsettled
prerequisite, so it delays only the questions downstream of it; ask the next
independent frontier question in the same turn. Fold the result in as fact
when it returns. Put only decisions to the user.

Never implement while digging.

Question format:

```
### Q[番号]: [質問文]

[なぜこの質問が重要か]

- **A** — [選択肢]
- **B** — [選択肢]
- ...

**推奨: [A/B/...]** — [理由]
```

Push at most twice on the same point. A third push is interrogation: the user
genuinely cannot decide, so record it as open and move on. Answer 「両方対応で」
by asking which one wins when they conflict. When an answer contradicts an
earlier one, quote both immediately and ask which holds.

The dig is done when the frontier is empty: every branch visited, every
dispatched lookup returned, and nothing left silently assumed — an assumption
you would otherwise carry into the summary is either asked now or listed
under 未決 as 仮置き. Then say so and ask for confirmation before summarising:

```
フロンティアが空になりました。決定 [N] 件、未決 [M] 件です。認識が揃ったものとしてまとめに進んでよいですか？（掘り足りない点があれば挙げてください）
```

Write the summary only after the user confirms; a gap they name is the new
frontier. Continue if the user asks for more.

Summary format:

```
## まとめ

### 決まったこと
- [決定] — [理由]

### 未決のまま残したこと
- [論点] — [決めるには何が必要か]
```
