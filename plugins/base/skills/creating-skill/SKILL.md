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

## Skill Structure

### YAML Front Matter

```yaml
---
name: example-skill        # lowercase, numbers, hyphens only (max 64 chars)
description: Specific description  # max 1024 chars, written in third person
---
```

**Naming Conventions** (gerund form recommended):
- ✓ `processing-pdfs`, `analyzing-spreadsheets`, `managing-databases`
- ✗ `helper`, `utils`, `anthropic-helper`

### Writing Effective Descriptions

**Always write in third person**:
- ✓ "Processes Excel files and generates reports"
- ✗ "I can help you process Excel files"

**Be specific and include key terms**:
```yaml
description: Extracts text and tables from PDF files and fills forms. Use when mentioning PDF files, forms, or document extraction.
```

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
- `name`: Max 64 chars, lowercase/numbers/hyphens only, no XML tags
- `description`: Max 1024 chars, non-empty, no XML tags

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

### Good SKILL.md

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

## Analogy: Think of Claude as a Robot Exploring Paths

- **Narrow bridge** (low freedom): Provide precise instructions
- **Open field** (high freedom): Indicate general direction
