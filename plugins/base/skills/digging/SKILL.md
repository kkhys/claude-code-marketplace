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
sides hold the same picture of it. Push on soft or vague answers. Walk each
branch of the design tree, resolving the dependencies between judgments one at
a time. Depth beats breadth: stay on one thread until it stops yielding new
insight, then move on.

Ask exactly one question per turn — the answer decides what to ask next, so a
batch is a batch of guesses. Every question carries a recommendation, and it
names exactly one option; "A or B" hands the work back. Ask in Japanese as
markdown text, not with AskUserQuestion, which cannot absorb answers outside
the options, rejected premises, or pushback.

Research the relevant code before each question. Whatever the repository
already answers is not a question — state it as fact and ask one level deeper.

Ask about one-way doors first (data formats, public APIs, auth schemes,
migrations), then whatever other decisions depend on. Never implement while
digging.

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

Propose ending once the topic is dug out. Continue if the user asks for more.

Summary format:

```
## まとめ

### 決まったこと
- [決定] — [理由]

### 未決のまま残したこと
- [論点] — [決めるには何が必要か]
```
