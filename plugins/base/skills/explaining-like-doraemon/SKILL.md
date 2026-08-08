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

Re-explain `$ARGUMENTS` — or, when blank, the previous answer the user got
stuck on — as a dialogue between のび太 and ドラえもん, in Japanese, then
restate it precisely. Never invent a fresh topic; this skill re-explains what
is already on screen.

## The dialogue

The format earns its length only because のび太 can say the wrong thing out
loud where a monologue can only assert. Before writing, ask what someone
plausibly gets wrong here; those misconceptions are のび太's lines, and they
set the order of the piece. If のび太 only nods along —「へえ、すごい！」—
the format has bought nothing and cost length.

- のび太 asks in concrete terms —「なんで同じこと2回も書かなきゃいけないの？」,
  not 「抽象化とは何ですか」— proposes fixes that are reasonable and wrong,
  and pushes back when a metaphor feels off.
- ドラえもん connects to what のび太 already lives with (給食の当番、ジャイアンの
  リサイタル、0点のテスト), grants the right part before correcting —
  「そこまでは合ってる。でもね」— and says where every metaphor breaks:
  「ただし本物はここがちがってね」. An unbounded metaphor is a falsehood the
  reader will trust precisely because it was easy to picture.
- Reach for a ひみつ道具 only when the mapping is genuinely tight (どこでもドア
  for a symlink, タイムふろしき for a rollback). A gadget dragged in for flavor
  reads as costume.

One concept per exchange, each resting on the one before; four to eight
exchanges is typical. Stop once the last thing worth misunderstanding has been
cleared up.

## Format

```
のび太「[素朴な疑問、または間違った推測]」

ドラえもん「[すでに知っているものへの接続]」

のび太「[じゃあ○○ってこと？ ← 半分合っていて半分ズレた解釈]」

ドラえもん「[合っている部分を認める → 訂正 → 比喩の限界]」

...
```

Close with:

```
---

## 技術的に言うと

- [会話で使った比喩] → [正確な用語]
- ...

[比喩では表せなかった注意点を1〜2行、あれば]

### 該当箇所
- `path/to/file.ts:42` — [その行に何があるか]
```

This closing section buys back the precision the dialogue traded away — the
exact terms, identifiers, and paths that got softened into metaphor, so the
user can grep for them. Read the code before naming a path or a line; a wrong
reference costs more than an omitted one. Drop 該当箇所 when the subject is
not code.

## When not to use this

An answer that was long rather than hard only gets longer as a dialogue — say
so and offer a plain summary instead. Reach for the dialogue when a concept is
the obstacle, not volume.
