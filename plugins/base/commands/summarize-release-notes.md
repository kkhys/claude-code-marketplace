---
description: Summarize recent Claude Code release notes in chronological order
---

# Summarize Release Notes

Summarize Claude Code release notes that are in the conversation context.

## Prerequisites

This command expects that `/release-notes` (built-in CLI command) has already been run in the conversation. If the release notes are not found in context, ask the user to run `/release-notes` first.

## Instructions

1. Locate the release notes output from the conversation context
2. Identify the latest version and summarize only that version's release notes
3. Summarize all notable items in bullet points using the user's preferred language
4. At the end, highlight 2-3 items that are especially noteworthy or actionable
