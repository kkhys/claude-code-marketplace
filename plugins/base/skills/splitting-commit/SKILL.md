---
name: splitting-commit
description: Split large changes into logical commits by semantic meaning. Always consult this skill when the user wants to organize uncommitted changes into multiple commits. Trigger phrases include "split commits", "organize into commits", "break up changes", "separate commits", "logical commits", "コミット分割", "コミットを分けて", "コミットを整理", "変更を整理してコミット", "変更をコミットに分割", "うまくコミット分割", "コミット分割して", "コミットどう分ける". Also trigger when the user describes multiple types of uncommitted changes that need organizing — e.g., mentioning a mix of bug fixes and features, refactoring and new code, renames and logic changes, or any situation where changes span multiple concerns. Use when preparing changes for a PR with mixed concerns, or as part of the publish-pr workflow. Do not use for single-concern changes — those go directly to formatting-commit.
---

# Splitting Commits

Split uncommitted changes into a sequence of focused commits, each representing one logical concern. The goal is a commit history that tells a story a reviewer can follow — and that `git bisect` and `git revert` can act on cleanly.

## When to Split

Split when changes span multiple concerns. A "concern" is a unit of intent: a bug fix, a feature, a refactoring, a dependency update. If the change fits in a single Conventional Commits subject line without "and", it's one concern — commit it directly with `formatting-commit` instead.

Don't over-split. Three related files changed for one feature = one commit, not three. A rename touching 12 files = one commit. The question is always: "Would a reviewer want to see these together or separately?"

## Workflow

### 1. Survey

```bash
git status
git diff --stat
git diff
```

Read the diff carefully. Before grouping, understand what every change does and why.

### 2. Plan

Identify distinct concerns and map files to each. Write the plan out before staging anything — this catches ordering mistakes early and lets you reason about the whole sequence.

Consider:
- Dependencies: Utility/infrastructure changes come before features that use them. Schema before code that reads it.
- Reviewability: A reviewer reads commits in order. Earlier commits should build context for later ones.
- Revertability: Could you `git revert` any single commit without breaking the others? If not, those changes belong together.

When a file touches multiple concerns, put it in the dominant one. Clean file-level splits are more reliable than attempting per-hunk staging — and almost always sufficient.

### 3. Execute

For each group, in dependency order:

```bash
git add <file1> <file2> ...
git diff --cached --stat
git diff --cached
```

After staging, invoke `formatting-commit` to compose the message and create the commit. Then move to the next group and repeat.

### 4. Verify

```bash
git log --oneline origin/main..HEAD
```

The log should read as a coherent narrative. If something looks off, `git reset --soft HEAD~N` and re-split.

## Split Patterns

| Situation | Commits | Why |
|---|---|---|
| Feature + its tests | 1 | Tests validate the feature — they're the same concern |
| Feature + unrelated bug fix found along the way | 2 | Independent concerns with no dependency |
| Refactor + feature built on it | 2 (refactor first) | Feature depends on refactor; separating makes the refactor reviewable on its own |
| Bug fix + feature that exposed the bug | 2 (fix first) | Fix is independently valuable and may need to be cherry-picked |
| Dependency update + code adapting to new API | 1 | Inseparable — the old code breaks without the update |
| Config + code using new config | 1 if tightly coupled, 2 if config is independently useful | Judgment call based on whether the config stands alone |
| Rename/move + logic changes | 2 (rename first) | Pure renames produce clean diffs; mixing in logic changes hides them |

## Anti-patterns

- Splitting by file instead of by concern: produces incoherent commits with no clear intent.
- Separating tests from implementation: if the tests verify the feature, they ship together.
- Creating "cleanup" commits for changes that only make sense in context of the feature they enable.
- Over-splitting trivial changes: a typo fix + import cleanup = one `chore` commit, not two.
