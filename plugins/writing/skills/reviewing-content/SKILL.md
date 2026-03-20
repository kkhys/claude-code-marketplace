---
name: reviewing-content
description: Orchestrate writing review agents to provide comprehensive feedback on blog posts, articles, and essays. Use when the user asks to review, check, or proofread a blog post, article, essay, or long-form written content — NOT for emails, chat messages, commit messages, or short transactional text. Trigger phrases include 'review this article', 'check my writing', 'proofread this post', 'improve this post', 'この記事をレビュー', '記事をチェック', 'ブログ記事のフィードバック', or when a user shares a draft .md file for content feedback. Automatically selects the appropriate combination of content-reviewer, language-editor, readability-enhancer, and technical-writer agents based on article characteristics.
allowed-tools: Agent, Read, Glob, Grep
---

# Content Review Orchestration

Review articles by selecting and running the appropriate specialist agents in parallel, then consolidating their feedback into a single actionable report.

## Process

1. Read the target article in full
2. Select which agents to run based on the content
3. Spawn selected agents in parallel
4. Consolidate feedback into a unified report

## Agent Selection

Analyze the article content to determine which agents are relevant. The goal is to avoid wasting tokens on agents whose expertise does not apply.

| Agent | subagent_type | Run when | Skip when |
|---|---|---|---|
| content-reviewer | `writing:content-reviewer` | Always — structure and logic apply to all content | Never |
| language-editor | `writing:language-editor` | Always — grammar and style apply to all content | Never |
| readability-enhancer | `writing:readability-enhancer` | Default include | Very short content (<300 words) with simple structure |
| technical-writer | `writing:technical-writer` | Article contains code blocks, technical concepts, API references, or documentation-style content | Purely personal, creative, or opinion writing with no technical elements |

Tell the user which agents you selected and why before spawning them.

## Agent Spawn

Spawn all selected agents in parallel using the Agent tool. Each agent needs:

- The full path to the article
- Instruction to read and review the article according to its specialization
- Output format instructions (below)

### Prompt Template

Use this as the base prompt for each agent, adjusting the specialization reference:

```
Review the following article according to your specialization.

Article: {article_path}

Read the article in full, then provide feedback. Communicate entirely in Japanese.

Organize findings by priority:
1. Critical — issues that significantly harm quality or correctness (must fix)
2. Warning — issues that noticeably reduce quality (should fix)
3. Suggestion — improvements that would enhance the piece (nice to have)

For each finding, include:
- Location: section heading or paragraph reference (quote the first few words)
- Issue: what the problem is
- Fix: specific, actionable improvement

Keep feedback concise. Skip praise — focus only on what can be improved.
```

## Consolidation

After all agents complete, synthesize their outputs into a single report for the user.

### Deduplication

Multiple agents may flag the same issue from different angles (e.g., content-reviewer notes a confusing paragraph, readability-enhancer also flags it). Merge these into one item, noting which perspectives identified it. Keep the most actionable fix suggestion.

### Priority Adjustment

- Issues flagged by 2+ agents: escalate one level (suggestion becomes warning, warning becomes critical)
- Technical inaccuracies from technical-writer: always critical regardless of other signals
- Structural issues from content-reviewer that affect comprehension: always critical

### Report Format

Present the consolidated report in this structure:

```
## Overview
Brief assessment of overall quality (2-3 sentences). Note the article's strengths
in one sentence, then summarize the key areas for improvement.

## Critical
Items that must be addressed before publishing.
Each item: location, issue, recommended fix, which agent(s) flagged it.

## Warning
Items that should be addressed to improve quality.
Same format as critical.

## Suggestion
Optional improvements.
Same format as critical.

## Agent Details
For each agent that ran, a collapsible summary of its full review
(use <details> tags) for users who want the complete perspective.
```

If a priority category has no items, omit it entirely. Do not include empty sections.
