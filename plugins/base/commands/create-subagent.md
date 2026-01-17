---
description: Create custom subagents with YAML frontmatter, system prompts, and tool restrictions
argument-hint: <subagent description or purpose>
model: claude-opus-4-5
---

**IMPORTANT**: Invoke the `creating-subagent` skill before proceeding.

# Create Subagent

Create Claude Code subagents following best practices for structure, descriptions, tool restrictions, and permission modes.

1. Invoke `creating-subagent` skill
2. Follow the subagent creation guidelines defined in the skill
3. Ask user for subagent location (`.claude/agents/` for project or `~/.claude/agents/` for user scope)
4. Ensure proper frontmatter configuration with name, description, and appropriate tool restrictions
