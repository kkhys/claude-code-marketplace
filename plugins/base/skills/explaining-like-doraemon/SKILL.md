---
name: explaining-like-doraemon
description: Re-explain a difficult answer as a Doraemon-Nobita dialogue, then restate it in precise terms
argument-hint: "[topic, or blank for the previous answer]"
disable-model-invocation: true
disallowed-tools:
  - Edit
  - Write
  - NotebookEdit
---

# Explaining Like Doraemon

Take something in this session the user could not get a grip on and re-explain
it as a dialogue between のび太 and ドラえもん, then restate it precisely.

The subject is `$ARGUMENTS` when given, otherwise the previous answer — usually
the part that just made the user stop. Never invent a fresh topic; this skill
re-explains what is already on screen.

## Why a dialogue

The dialogue is not worth its length for the voices. It is worth it because
のび太 can say the wrong thing out loud. A monologue can only assert. A dialogue
can voice the misconception the reader is actually holding and then take it
apart in front of them.

So before writing anything, ask: what does someone plausibly get wrong here?
Those misconceptions are のび太's lines, and they set the order of the whole
piece. If のび太 only nods along —「へえ、すごい！」— the format has bought
nothing and cost length. That is the failure to avoid above all others.

## The two voices

のび太 asks in concrete terms. Not 「抽象化とは何ですか」 but 「なんで同じこと
2回も書かなきゃいけないの？」. He proposes fixes that are reasonable and wrong.
He pushes back when a metaphor feels off, because a reader who noticed the same
gap needs it addressed rather than glossed.

ドラえもん connects to what のび太 already lives with: 給食の当番、ジャイアンの
リサイタル、0点のテスト、押し入れ. He grants the right part before correcting —
「そこまでは合ってる。でもね」 — since a correction that erases the whole guess
never teaches which part was wrong.

Reach for a ひみつ道具 only when the mapping is genuinely tight: どこでもドア for
a symlink or a tunnel, もしもボックス for a feature flag or a staging
environment, タイムふろしき for a rollback. A gadget dragged in for flavor reads
as costume, not explanation.

## Bound every metaphor

Every metaphor breaks somewhere. Say where, inside the dialogue, in ドラえもん's
voice:「ただし本物はここがちがってね」. An unbounded metaphor is a falsehood the
reader will go on to trust, and they will trust it precisely because it was easy
to picture.

## Pacing

One concept per exchange, ordered so each rests on the one before. Length
follows the concept count rather than a target — four to eight exchanges is
typical. Stop once the last thing worth misunderstanding has been cleared up.

Write the dialogue in Japanese.

## Format

```
のび太「[素朴な疑問、または間違った推測]」

ドラえもん「[すでに知っているものへの接続]」

のび太「[じゃあ○○ってこと？ ← 半分合っていて半分ズレた解釈]」

ドラえもん「[合っている部分を認める → 訂正 → 比喩の限界]」

...
```

Close with the technical restatement:

```
---

## 技術的に言うと

- [会話で使った比喩] → [正確な用語]
- ...

[比喩では表せなかった注意点を1〜2行、あれば]

### 該当箇所
- `path/to/file.ts:42` — [その行に何があるか]
```

The dialogue traded precision for intuition; this section buys it back. It is
not a summary of the conversation — it is the exact vocabulary, identifiers,
commands, and paths that got softened into metaphor, so the user can grep for
them and use them with other people. Read the code before naming a path or a
line; a wrong reference costs more than an omitted one. Drop 該当箇所 entirely
when the subject is not code.

## When not to use this

A previous answer that was long rather than hard only gets longer as a dialogue.
Say so and offer a plain summary instead. Same when showing the code or running
the command settles it faster. Reach for the dialogue when a concept is the
obstacle — not when the obstacle is volume, or an unfamiliar API that a link
would fix.
