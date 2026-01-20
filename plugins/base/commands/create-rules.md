---
description: Create Claude Code rules for .claude/rules/ directory
argument-hint: <rule topic or file type>
---

**IMPORTANT**: Invoke the `creating-rules` skill before proceeding.

# Create Rules

Create Claude Code rules (.claude/rules/*.md) with YAML frontmatter and optional path-specific scoping.

1. Invoke `creating-rules` skill
2. Ask user for rule scope (global or path-specific) and location
3. Create focused, single-topic rule file
4. Use descriptive filename (e.g., `typescript.md`, `testing.md`)
