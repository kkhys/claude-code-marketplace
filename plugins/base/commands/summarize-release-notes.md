---
description: Summarize recent Claude Code release notes in chronological order
---

# Summarize Release Notes

Summarize Claude Code release notes that are in the conversation context.

## Prerequisites

This command expects that `/release-notes` (built-in CLI command) has already been run in the conversation. If the release notes are not found in context, ask the user to run `/release-notes` first.

## Instructions

1. Locate the release notes output from the conversation context
2. Summarize all notable items — do not filter by the user's environment or project. Include everything that a developer would find useful to know about.
3. Present items in chronological order (oldest to newest), grouped by version
4. For each version, write a concise bullet-point summary in the user's preferred language
5. Omit versions that only contain minor internal bugfixes with no user-facing impact
6. At the end, highlight 2-3 items that are especially noteworthy or actionable
