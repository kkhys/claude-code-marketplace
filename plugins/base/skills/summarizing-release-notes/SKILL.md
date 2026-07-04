---
name: summarizing-release-notes
description: Summarize recent Claude Code release notes in chronological order.
when_to_use: >-
  Use when the user asks to summarize Claude Code release notes already
  present in the conversation, typically right after running the built-in
  /release-notes command — "リリースノートまとめて", "summarize the release
  notes", "what's new in Claude Code".
---

# Summarize Release Notes

Summarize Claude Code release notes that are in the conversation context.

## Prerequisites

This skill expects that `/release-notes` (built-in CLI command) has already been run in the conversation. If the release notes are not found in context, ask the user to run `/release-notes` first.

## Instructions

1. Locate the release notes output from the conversation context
2. Identify the latest version and summarize only that version's release notes
3. Summarize all notable items in bullet points using the user's preferred language
4. At the end, highlight 2-3 items that are especially noteworthy or actionable
