---
name: using-serena
description: Serena MCP expert for efficient code editing and analysis. Use when starting projects, editing code, or refactoring. Prioritize symbol-based operations over full-file reads.
---

# Serena MCP Expert Guide

Serena is an MCP server for efficient code navigation and editing through LSP-based symbol operations.

## When to Use

- **Project initialization (required)**: When `.serena` directory doesn't exist
- **Code editing/analysis (priority)**: Use symbol-based operations instead of reading entire files
- **Refactoring**: Analyze dependencies before making changes

## Core Principles

1. **Full-file read is last resort**: Search symbols first with Serena
2. **Token efficiency**: Symbol-based operations drastically reduce token usage
3. **Validation before changes**: Always call `think_about_task_adherence()` before editing
4. **Use regex mode**: Prefer `replace_content` with regex mode and wildcards
5. **Worktree usage**: Copy `.serena` from parent directory (`cp -r ../.serena .serena`)

## Essential Workflow

### 1. Project Initialization (First time only)

```bash
ls -la .serena

# If not exists
mcp__serena__activate_project(project=".")
mcp__serena__check_onboarding_performed()
mcp__serena__onboarding()  # If not performed
```

### 2. Code Analysis

#### Get Symbol Overview

```python
mcp__serena__get_symbols_overview(
  relative_path="src/file.ts",
  depth=0  # 0=top-level only, 1=includes direct children
)
```

#### Find Symbols

```python
# Search by name path pattern
mcp__serena__find_symbol(
  name_path_pattern="ClassName/methodName",  # Relative path
  name_path_pattern="/ClassName/methodName", # Absolute path (exact match)
  name_path_pattern="methodName",            # Simple name
  relative_path="src/",                      # Restrict search scope
  include_body=True,                         # Include source code
  depth=1,                                   # Include children
  substring_matching=True                    # Substring search
)
```

#### Analyze Dependencies

```python
mcp__serena__find_referencing_symbols(
  name_path="functionName",
  relative_path="src/file.ts"  # File specification required
)
```

#### Pattern Search

```python
mcp__serena__search_for_pattern(
  substring_pattern="TODO|FIXME",           # Regex pattern
  relative_path="src/",                     # Search scope
  paths_include_glob="*.ts",                # Include files
  paths_exclude_glob="*test*",              # Exclude files
  restrict_search_to_code_files=True,       # Code files only
  context_lines_before=2,                   # Context lines
  context_lines_after=2
)
```

### 3. Code Editing

#### Replace Symbol Body (Recommended)

```python
mcp__serena__replace_symbol_body(
  name_path="methodName",
  relative_path="src/file.ts",
  body="function methodName() { ... }"  # Include signature, exclude docstring/imports
)
```

#### Replace Content (Flexible)

```python
mcp__serena__replace_content(
  relative_path="src/file.ts",
  needle="beginning.*?end",  # Regex recommended
  repl="new content",
  mode="regex",              # "literal" or "regex"
  allow_multiple_occurrences=False
)
```

#### Insert Before/After Symbol

```python
# Add import statements
mcp__serena__insert_before_symbol(
  name_path="firstSymbol",
  relative_path="src/file.ts",
  body="import { X } from 'y';\n"
)

# Add new method
mcp__serena__insert_after_symbol(
  name_path="lastMethod",
  relative_path="src/file.ts",
  body="\n  newMethod() { ... }"
)
```

#### Rename Symbol

```python
mcp__serena__rename_symbol(
  name_path="oldName",
  relative_path="src/file.ts",
  new_name="newName"  # Changes across entire codebase
)
```

### 4. File Operations

```python
# List directory
mcp__serena__list_dir(relative_path="src/", recursive=True)

# Find files
mcp__serena__find_file(file_mask="*.test.ts", relative_path="src/")

# Read file (only when symbol operations are not possible)
mcp__serena__read_file(
  relative_path="config.json",
  start_line=0,
  end_line=50
)

# Create/overwrite file
mcp__serena__create_text_file(
  relative_path="src/new-file.ts",
  content="// content"
)
```

### 5. Project Knowledge Management (Memory)

```python
# List memories
mcp__serena__list_memories()

# Read memory
mcp__serena__read_memory(memory_file_name="architecture.md")

# Write memory
mcp__serena__write_memory(
  memory_file_name="decisions.md",
  content="# Design Decisions\n..."
)

# Edit memory
mcp__serena__edit_memory(
  memory_file_name="decisions.md",
  needle="old text",
  repl="new text",
  mode="literal"  # or "regex"
)

# Delete memory
mcp__serena__delete_memory(memory_file_name="outdated.md")
```

### 6. Thinking Tools

```python
# Call after gathering information
mcp__serena__think_about_collected_information()

# Call before code changes (required)
mcp__serena__think_about_task_adherence()

# Call when task is complete
mcp__serena__think_about_whether_you_are_done()
```

### 7. Other Operations

```python
# Execute shell command
mcp__serena__execute_shell_command(
  command="npm run build",
  cwd=None  # None = project root
)

# Get current configuration
mcp__serena__get_current_config()

# Switch modes
mcp__serena__switch_modes(modes=["editing", "interactive"])
```

## LSP Symbol Kinds

For `include_kinds`/`exclude_kinds` parameters:

| Value | Kind | Value | Kind |
|-------|------|-------|------|
| 1 | file | 14 | constant |
| 2 | module | 15 | string |
| 3 | namespace | 16 | number |
| 4 | package | 17 | boolean |
| 5 | class | 18 | array |
| 6 | method | 19 | object |
| 7 | property | 20 | key |
| 8 | field | 21 | null |
| 9 | constructor | 22 | enum member |
| 10 | enum | 23 | struct |
| 11 | interface | 24 | event |
| 12 | function | 25 | operator |
| 13 | variable | 26 | type parameter |

## Best Practices

- Always initialize project before using other tools
- Use symbol operations before reading entire files
- Call thinking tools at appropriate stages
- Use regex mode for flexible content replacement
- Store architectural decisions and patterns in memory
- Analyze dependencies before refactoring

## Reference

Official documentation: https://oraios.github.io/serena/_sources/02-usage/050_configuration.md
