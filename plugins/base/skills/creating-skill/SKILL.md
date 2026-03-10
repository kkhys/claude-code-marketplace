---
name: creating-skill
description: Provides best practices and guidelines for creating Claude Code skills. Use when you need help with skill structure, naming conventions, writing effective descriptions, progressive disclosure patterns, and evaluation methods.
---

# Skill Creation Guide

Practical guidelines for creating skills that Claude Code can effectively discover and use.

## Core Principles

### 1. Brevity is Key

**Claude is already smart** - Only add context that Claude doesn't already have.

```markdown
✓ Good example (concise):
## Extracting PDF Text
Use pdfplumber:
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()

✗ Bad example (verbose):
PDF (Portable Document Format) files are...
First, you need to install using pip...
```

**Token Budget**: Keep SKILL.md body under 500 lines

### 2. Set Appropriate Freedom Levels

Adjust specificity level to match task fragility:

**High Freedom** (multiple approaches valid):
```markdown
## Code Review Process
1. Analyze code structure and organization
2. Check for potential bugs
3. Suggest readability improvements
```

**Low Freedom** (operation is fragile):
```markdown
## Database Migration
Execute this script exactly:
python scripts/migrate.py --verify --backup
Do not modify the command.
```

### 3. Test with All Models

Test your skill with all models you plan to use (Haiku, Sonnet, Opus).

## Skill Locations and Priority

Where you store a skill determines who can use it:

| Location | Path | Applies to |
|---|---|---|
| Enterprise | Managed settings | All users in org |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin is enabled |

Priority: enterprise > personal > project. Plugin skills use `plugin-name:skill-name` namespace (no conflicts).

**Nested directory discovery**: When editing files in subdirectories, Claude also looks for skills in `packages/frontend/.claude/skills/` etc. Supports monorepo setups.

**Note**: `.claude/commands/` files still work and support the same frontmatter. Skills are recommended since they support additional features like supporting files.

## Skill Structure

### YAML Front Matter

All fields are optional. Only `description` is recommended so Claude knows when to use the skill.

```yaml
---
name: example-skill        # lowercase, numbers, hyphens only (max 64 chars)
description: Specific description  # max 1024 chars, written in third person
---
```

| Field | Required | Description |
|---|---|---|
| `name` | No | Display name. If omitted, uses the directory name. Lowercase letters, numbers, and hyphens only (max 64 chars). |
| `description` | Recommended | What the skill does and when to use it. Claude uses this to decide when to apply the skill. If omitted, uses the first paragraph of markdown content. |
| `argument-hint` | No | Hint shown during autocomplete to indicate expected arguments. Example: `[issue-number]` or `[filename] [format]`. |
| `disable-model-invocation` | No | Set to `true` to prevent Claude from automatically loading this skill. Use for workflows you want to trigger manually with `/name`. Default: `false`. |
| `user-invocable` | No | Set to `false` to hide from the `/` menu. Use for background knowledge users shouldn't invoke directly. Default: `true`. |
| `allowed-tools` | No | Tools Claude can use without asking permission when this skill is active. |
| `model` | No | Model to use when this skill is active. |
| `context` | No | Set to `fork` to run in a forked subagent context. |
| `agent` | No | Which subagent type to use when `context: fork` is set. Built-in: `Explore`, `Plan`, `general-purpose`, or custom subagent from `.claude/agents/`. |
| `hooks` | No | Hooks scoped to this skill's lifecycle. |

### Invocation Control

| Frontmatter | You can invoke | Claude can invoke | When loaded into context |
|---|---|---|---|
| (default) | Yes | Yes | Description always in context, full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context, full skill loads when you invoke |
| `user-invocable: false` | No | Yes | Description always in context, full skill loads when invoked |

Use `disable-model-invocation: true` for workflows with side effects (deploy, commit, send messages).
Use `user-invocable: false` for background knowledge that isn't actionable as a command.

**Naming Conventions** (gerund form recommended):
- Good: `processing-pdfs`, `analyzing-spreadsheets`, `managing-databases`
- Bad: `helper`, `utils`, `anthropic-helper`

### Writing Effective Descriptions

**Always write in third person**:
- Good: "Processes Excel files and generates reports"
- Bad: "I can help you process Excel files"

**Be specific and include key terms**:
```yaml
description: Extracts text and tables from PDF files and fills forms. Use when mentioning PDF files, forms, or document extraction.
```

### Available String Substitutions

| Variable | Description |
|---|---|
| `$ARGUMENTS` | All arguments passed when invoking the skill. If not present in content, arguments are appended as `ARGUMENTS: <value>`. |
| `$ARGUMENTS[N]` | Access a specific argument by 0-based index. `$ARGUMENTS[0]` for the first argument. |
| `$N` | Shorthand for `$ARGUMENTS[N]`. `$0` for first, `$1` for second. |
| `${CLAUDE_SESSION_ID}` | Current session ID. Useful for logging or session-specific files. |
| `${CLAUDE_SKILL_DIR}` | Directory containing the skill's `SKILL.md`. Use to reference bundled scripts/files. |

Example:
```yaml
---
name: migrate-component
description: Migrate a component from one framework to another
---
Migrate the $0 component from $1 to $2.
Preserve all existing behavior and tests.
```

### Dynamic Context Injection

The `` !`command` `` syntax runs shell commands **before** the skill content is sent to Claude. Output replaces the placeholder.

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
---
## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

This is preprocessing, not something Claude executes. Claude only sees the final result.

## Progressive Disclosure Patterns

### Pattern 1: High-Level Guide with References

```markdown
## Quick Start
[Basic code example]

## Advanced Features
**Form Filling**: See [FORMS.md](FORMS.md)
**API Reference**: See [REFERENCE.md](REFERENCE.md)
```

### Pattern 2: Domain-Specific Organization

```
skill/
├── SKILL.md (overview)
└── reference/
    ├── finance.md
    ├── sales.md
    └── product.md
```

### Important Rules

- **Keep references 1 level deep only** - Link directly from SKILL.md
- **Include table of contents for long reference files** (100+ lines)
- **Avoid deeply nested references**

## Workflows and Feedback Loops

### Checklist Pattern

```markdown
## Research Synthesis Workflow

Progress checklist:
- [ ] Step 1: Read all sources
- [ ] Step 2: Identify key themes
- [ ] Step 3: Cross-reference claims
- [ ] Step 4: Create structured summary
- [ ] Step 5: Verify citations

**Step 1: Read all sources**
[Detailed instructions]

**Step 2: Identify key themes**
[Detailed instructions]
```

### Validation Loop Pattern

```markdown
## Document Editing Process
1. Make edits to XML
2. **Validate immediately**: python validate.py
3. If validation fails:
   - Check errors
   - Fix issues
   - Re-validate
4. **Only proceed on success**
5. Test output
```

## Content Guidelines

### ✓ Do's

- **Use consistent terminology** - Pick one term and stick with it
- **Provide concrete examples** - Real examples, not abstract ones
- **Provide templates** - Clear structure for output formats
- **Conditional workflows** - Guide Claude through decision points

### ✗ Don'ts

- **Time-sensitive information** - "Before August 2025..."
- **Windows-style paths** - Use `scripts/file.py` instead of `scripts\file.py`
- **Too many options** - Provide defaults, alternatives only when needed
- **Vague descriptions** - "Helps with documents"

## Skills with Executable Code

### Utility Scripts

```markdown
## Utility Scripts

**analyze_form.py**: Extract form fields from PDF
python scripts/analyze_form.py input.pdf > fields.json

**validate_boxes.py**: Check for overlapping bounding boxes
python scripts/validate_boxes.py fields.json
```

### Error Handling

```python
# ✓ Good: Explicitly handle errors
def process_file(path):
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        print(f"File {path} not found, creating default")
        with open(path, 'w') as f:
            f.write('')
        return ''

# ✗ Bad: Leave it to Claude
def process_file(path):
    return open(path).read()  # May fail
```

### Verifiable Intermediate Output

Use "plan-validate-execute" pattern for complex tasks:

```markdown
## Batch Update Workflow
1. Analyze: Identify fields
2. **Create plan file**: changes.json
3. **Validate plan**: python validate_plan.py changes.json
4. Execute: Apply changes
5. Verify: Validate output
```

## Evaluation and Iteration

### Evaluation-Driven Development

1. **Identify gaps** - Run Claude without skill
2. **Create evaluations** - Build 3 scenarios
3. **Establish baseline** - Measure performance
4. **Write minimal instructions** - Just enough to pass evaluations
5. **Iterate** - Run and improve

### Iterative Development with Claude

**Creating new skills**:
1. Complete task with Claude A (normal prompts)
2. Identify reusable patterns
3. Ask Claude A to create skill
4. Review for brevity
5. Test with Claude B (new instance)
6. Iterate based on observations

**Improving existing skills**:
1. Use real workflows with Claude B
2. Observe Claude B's behavior
3. Return to Claude A for improvements
4. Review Claude A's suggestions
5. Apply changes and test
6. Repeat based on usage

## Checklist

### Core Quality
- [ ] Description is specific and includes key terms
- [ ] Description includes what it does and when to use
- [ ] SKILL.md body is under 500 lines
- [ ] No time-sensitive information
- [ ] Consistent terminology throughout
- [ ] Examples are concrete
- [ ] File references are 1 level deep
- [ ] Clear steps in workflows

### Code and Scripts
- [ ] Scripts solve problems
- [ ] Error handling is explicit
- [ ] All values are justified
- [ ] Required packages are listed
- [ ] No Windows-style paths
- [ ] Validation/verification steps
- [ ] Feedback loops

### Testing
- [ ] At least 3 evaluations
- [ ] Tested with Haiku, Sonnet, Opus
- [ ] Tested with real use scenarios

## Technical Notes

### YAML Front Matter Requirements
- `name`: Max 64 chars, lowercase/numbers/hyphens only
- `description`: Max 1024 chars, recommended but not required
- See the full field reference in the "YAML Front Matter" section above

### MCP Tool References
Use fully qualified tool names: `ServerName:tool_name`

Example:
```markdown
Use BigQuery:bigquery_schema tool to get schema
Use GitHub:create_issue tool to create issue
```

### Runtime Environment
- Claude accesses files via bash
- Scripts can be executed without loading content
- Use forward slashes (all platforms)
- Use descriptive file names

## Practical Examples

### Good Skill Structure

```
pdf-skill/
├── SKILL.md              # Main instructions
├── FORMS.md              # Form filling guide
├── reference.md          # API reference
└── scripts/
    ├── analyze_form.py
    └── fill_form.py
```

### Good SKILL.md (minimal)

```markdown
---
name: processing-pdfs
description: Extracts text and tables from PDF files and fills forms. Use when mentioning PDF files, forms, or document extraction.
---

# PDF Processing

## Quick Start
Extract text with pdfplumber:
[Code example]

## Advanced Features
**Form Filling**: See [FORMS.md](FORMS.md)
**API Reference**: See [reference.md](reference.md)
```

### Good SKILL.md (with subagent context)

`context: fork` runs the skill in isolation. The skill content becomes the prompt that drives the subagent (no access to conversation history). Only use with explicit task instructions, not guidelines-only content.

| Approach | System prompt | Task | Also loads |
|---|---|---|---|
| Skill with `context: fork` | From agent type | SKILL.md content | CLAUDE.md |
| Subagent with `skills` field | Subagent's markdown body | Claude's delegation message | Preloaded skills + CLAUDE.md |

```markdown
---
name: reading-unresolved-pr-comments
description: Fetches unresolved review comments from a GitHub PR and creates a fix plan. Use when reviewing PR feedback or resolving PR discussions.
model: opus
context: fork
agent: general-purpose
---

# Read Unresolved PR Comments
[Workflow instructions]
```

## Troubleshooting

**Skill not triggering**:
1. Check the description includes keywords users would naturally say
2. Verify the skill appears in `What skills are available?`
3. Invoke it directly with `/skill-name` to confirm it works

**Skill triggers too often**:
1. Make the description more specific
2. Add `disable-model-invocation: true` for manual-only invocation

**Claude doesn't see all skills**:
Skill descriptions are loaded at 2% of context window (fallback: 16,000 chars). Override with `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var. Run `/context` to check for excluded skills.
