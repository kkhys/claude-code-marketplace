# Third-party notices

Skills in this marketplace that are ported or adapted from other projects, with
their licenses. Each entry lists the upstream source and the derived files here.

## mattpocock/skills

- Source: https://github.com/mattpocock/skills (commit `068b6e0`)
- License: MIT — Copyright (c) 2026 Matt Pocock
- Derived files:
  - `plugins/base/skills/diagnosing-bugs/SKILL.md` — from `skills/engineering/diagnosing-bugs/SKILL.md`
  - `plugins/base/skills/diagnosing-bugs/scripts/hitl-loop.template.sh` — from `skills/engineering/diagnosing-bugs/scripts/hitl-loop.template.sh`
  - `plugins/base/skills/resolving-merge-conflicts/SKILL.md` — from `skills/engineering/resolving-merge-conflicts/SKILL.md`
  - `plugins/base/skills/creating-handoff/SKILL.md` — from `skills/productivity/handoff/SKILL.md`
  - `plugins/base/skills/writing-for-agents/SKILL.md` — from `skills/productivity/writing-for-agents/SKILL.md`
  - `plugins/base/skills/writing-for-agents/references/skill-mechanics.md` — from `skills/productivity/writing-for-agents/SKILL-MECHANICS.md`
  - `plugins/base/skills/digging/SKILL.md` — interview mechanics (design tree, frontier, facts vs decisions, completion gate) adapted from `skills/productivity/grilling/SKILL.md`

```
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## openai/codex

- Source: https://github.com/openai/codex (commit `a770e5b`), skill `.codex/skills/babysit-pr`
- License: Apache-2.0 — Copyright 2025 OpenAI
- Derived files (all modified from the originals):
  - `plugins/base/skills/babysitting-pr/SKILL.md` — from `.codex/skills/babysit-pr/SKILL.md`. Keeps the babysitting loop, the fix-vs-rerun ordering, review-comment handling, and the git-safety and final-report checklists; the terminal conditions, the Copilot review loop, and the long-poll watcher model are this project's own.
  - `plugins/base/skills/babysitting-pr/references/ci-heuristics.md` — from `.codex/skills/babysit-pr/references/heuristics.md` (branch-related vs flaky classification, decision tree, stop-and-ask conditions)
  - `plugins/base/skills/babysitting-pr/references/watcher-output.md` — from `.codex/skills/babysit-pr/references/github-api-notes.md` (the `gh` calls behind the snapshot)
  - `plugins/base/skills/babysitting-pr/scripts/pr-watch.sh`, `scripts/snapshot.jq` — snapshot/`actions` model from `.codex/skills/babysit-pr/scripts/gh_pr_watch.py`, reimplemented in bash + jq with long-polling instead of a streaming watch process

The upstream `NOTICE` file reads:

```
OpenAI Codex
Copyright 2025 OpenAI

This project includes code derived from [Ratatui](https://github.com/ratatui/ratatui), licensed under the MIT license.
Copyright (c) 2016-2022 Florian Dehau
Copyright (c) 2023-2025 The Ratatui Developers
```

The Apache-2.0 boilerplate notice that upstream applies to its sources:

```
Copyright 2025 OpenAI

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

## k16shikano gists (Japanese writing skills)

- Sources:
  - https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d — `japanese-tech-writing/SKILL.md`, plus `argument-gap-edit` posted in that gist's comments
  - https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432 — `cognitive-rhythm-writing/SKILL.md`
- License: Unlicense (public domain dedication). The author applies it to all
  their public gists — see https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063
- Derived files (all restructured for this marketplace; the norms themselves are
  kept close to the originals):
  - `plugins/base/skills/japanese-tech-writing/SKILL.md` — the always-applicable core (一文一行, 話題テスト, LLM 口調, 段落は論証の一歩, 未回収の緊張, 断定の境界) drawn from all three upstream skills. The two-mode workflow, the agent dispatch, and the consolidation format are this project's own
  - `plugins/base/skills/japanese-tech-writing/references/argument.md` — 「段落と論証の構成」「論証の厳密さ」「読者への誠実さ」 from `japanese-tech-writing`, merged with the detection types, inspection procedure, and repair policy from `argument-gap-edit`
  - `plugins/base/skills/japanese-tech-writing/references/rhythm.md` — from `cognitive-rhythm-writing`, plus 「読み手の負荷の管理」 from `japanese-tech-writing`
  - `plugins/base/skills/japanese-tech-writing/references/prose.md` — 「整形」「見出しの付け方」「視点と語り」「演出の抑制」「冗長の排除」 from `japanese-tech-writing`
  - `plugins/base/agents/argument-auditor.md`, `rhythm-designer.md`, `prose-auditor.md` — agent definitions written for this project, scoped to the reference above each one reads

The Unlicense text the author applies:

```
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org/>
```
