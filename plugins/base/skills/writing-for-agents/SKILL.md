---
name: writing-for-agents
description: >-
  Levers for writing any document an agent consumes — a skill, CLAUDE.md /
  AGENTS.md, an agent definition, a reference reached by a pointer: context
  pointers, the two loads, information hierarchy, completion criteria,
  leading words, pruning.
when_to_use: >-
  Always consult before creating or editing a SKILL.md, CLAUDE.md, AGENTS.md,
  an agent definition, or any reference file an agent will read — "write a
  skill", "improve this skill", "スキルを書いて", "スキルを改善", "CLAUDE.md
  を直して", "description を直して", "発火しない", "エージェント向けドキュメント".
  Also when a skill fires unreliably or too often (its pointer needs
  sharpening), or when a document has grown long and needs pruning or
  splitting. Complements skill-creator (drafting and evals) — this skill
  covers the writing itself.
argument-hint: "[path of a document to audit (optional)]"
---

# Writing for Agents

Reference for writing any document an agent consumes — a skill, an
`AGENTS.md` / `CLAUDE.md`, a doc reached by a pointer. The packaging differs;
the writing does not: the same levers make each one predictable — the agent
taking the same process every run, not producing the same output.

When the document is a skill, read `references/skill-mechanics.md` for the
invocation choice, splitting by invocation, and router skills. Frontmatter
keys, size limits, and the description truncation rule live in this
marketplace's CLAUDE.md; drafting and eval loops live in `skill-creator`.

If `$ARGUMENTS` names a document, audit it heading by heading against the
levers below and propose edits.

## Context pointers

A context pointer is a reference held in the agent's context that names some
out-of-context material and encodes the condition for reaching it. A skill's
description is one; a line in `AGENTS.md` naming a doc is the same object.
The pointer's wording, not its target, decides when the agent reaches the
material — and how reliably. A must-have target behind a weakly worded pointer
is a variance bug: sharpen the wording first, and inline the material only if
sharpening fails.

A pointer does two jobs — state what the material is, and list the branches
that should trigger reaching it (a branch is a distinct case the document
handles). Every word of an always-loaded pointer costs on every turn, so it
earns even harder pruning than the body:

- Front-load the leading word — the pointer is where it does its triggering
  work.
- One trigger per branch. Synonyms that rename a single branch are one branch
  written twice; keep only genuinely distinct branches.
- Cut identity the body already carries.

## The two loads

Every document and pointer you add spends one of two budgets:

- Context load — the cost of always-loaded material on the agent's window: an
  `AGENTS.md` line, a skill description, anything sitting in context every
  turn, spending tokens and attention whether or not it fires.
- Cognitive load — the cost on the human: which documents exist and when to
  reach for each. The human is the index. Not a cost to minimise — it is the
  price of human agency; spend it where human judgement matters, remove it
  where it does not.

Material reached only through a pointer escapes context load at the price of
the pointer's own line; material with no pointer at all rides entirely on
cognitive load.

## Information hierarchy

A document is built from two content types — steps (the ordered actions the
agent performs) and reference (definitions, rules, facts consulted on demand)
— that mix freely. The core decision is where each piece sits on the
information hierarchy, a ladder ranked by how immediately the agent needs it:

1. In-file step — the primary tier: what the agent does, in order.
2. In-file reference — consulted on demand; a flat peer-set of rules is a
   fine arrangement here.
3. Disclosed reference — pushed out into a separate file, reached by a
   context pointer, loaded only when the pointer fires.

Push too little down and the top bloats; push too much and you hide material
the agent actually needs. That tension is the whole decision.

Progressive disclosure is the move down the ladder — out of the main file
and behind a pointer — so the top stays legible. Not primarily a token
optimisation: it is how the hierarchy is protected. Branching is the cleanest
disclosure test: inline what every branch needs, and push behind a pointer
what only some branches reach. In-file reference that should have been
disclosed buries the steps and turns attending to them into a coin-flip.

Co-location is the within-file companion: keep a concept's definition, rules,
and caveats under one heading rather than scattered, so reading one part
brings its neighbours with it. (Distinct from duplication: that repeats one
meaning in two places; scattering fragments one meaning across many.)

Sprawl is the failure mode: a document simply too long, even when every line
is live and unique. Attention thins across the excess. The cure is the
ladder: disclose reference behind pointers, and split by branch or sequence
so each path carries only what it needs.

## Steps and completion criteria

Every step ends on a completion criterion — the condition that tells the
agent the work is done. Two properties make it a lever:

- Clarity — can the agent tell done from not-done? A vague bound
  ("understanding reached") invites premature completion: ending the step
  early because the visible steps still ahead — the post-completion steps —
  supply the pull, and the criterion's clarity is the resistance. Sharpen the
  bound first; only if it is irreducibly fuzzy and you observe the rush, hide
  the later steps by splitting the sequence — and hiding only works across a
  real context boundary (a hand-off or a subagent dispatch), never an inline
  call.
- Demand — how much it requires. "Every modified model accounted for" forces
  thorough work where "produce a change list" does not. Demand drives legwork
  — digging latent in the wording rather than written as its own step — and
  it is not step-bound: "every rule applied" binds a body of flat reference
  just as "every step done" binds a sequence.

The strongest criteria are both checkable and exhaustive.

## When to split

Splitting one document into two spends one of the two loads, so split only
when the cut earns it:

- By sequence — split a run of steps where the post-completion steps tempt
  the agent to rush the one in front of it. Beware the reverse: merging
  sequences exposes each step's later steps, inviting premature completion.
- By invocation — skill-specific: see `references/skill-mechanics.md`.

## Leading words

A leading word is a compact concept already living in the model's
pretraining that the agent thinks with while running the document (lesson,
fog of war, tracer bullets). Repeated as a token, never as a sentence, it
anchors a whole region of behaviour in the fewest tokens by recruiting priors
the model already holds. A made-up word recruits no priors — you pay in
definition tokens what a pretrained word gives free — so reach for an
existing word first.

It anchors twice. In the body, execution: the agent reaches for the same
behaviour every time the word appears. In a pointer, invocation: when the
same word lives in your prompts, your docs, and your codebase, the agent
links that shared language to the material and reaches it more reliably.

Hunt for restatements a leading word retires: "fast, deterministic,
low-overhead" → tight (a tight loop); "a loop you believe in" → red (the loop
goes red on the bug, or it doesn't). Fewer tokens, sharper hook. Assume every
document is carrying some — go find them.

Negation is the failure mode beside this lever: steering by prohibition drags
the forbidden behaviour into context and makes it more available, not less,
so the ban half-reads as an instruction to do the thing. Prompt the positive
— state the target behaviour so the banned one is never spoken. A
prohibition earns its place only as a hard guardrail you cannot phrase
positively; even then, pair it with the positive target so attention lands
on what to do.

## Pruning

- Keep each meaning in a single source of truth. Duplication costs
  maintenance and tokens, and inflates a meaning's prominence on the ladder
  past its real rank. (The accidental inverse of a leading word, which
  repeats a token on purpose, never the meaning.)
- The environment is a source of truth too — `package.json` scripts, config
  files, the directory layout, `--help` output — and a document that restates
  it is a cache, earning its load only when the lookup is expensive. Cache
  what the agent cannot find by looking: the unwritten convention, the reason
  behind a choice, the gotcha no config confesses. Leave the one-file,
  one-command lookups to the environment, where they cannot go stale.
- Check every line for relevance: does it still bear on what the document
  does? Without a pruning discipline the default fate is sediment: stale
  layers that settle because adding feels safe and removing feels risky.
  Shorter documents are easier to keep relevant.
- Hunt no-ops sentence by sentence: an instruction the model already obeys by
  default pays load to say nothing. The test — does it change behaviour
  versus the default? — is model-relative; settle it by running the document,
  not by debate. When a sentence fails, delete the whole sentence rather than
  trim words from it. The test also grades leading words: a word too weak to
  beat the default (be thorough) is a no-op, and the fix is a stronger word
  (relentless), not a different technique.
