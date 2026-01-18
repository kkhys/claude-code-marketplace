# Slash Command Examples

Practical examples for common use cases.

## Basic Commands

### Code Review
```markdown
---
description: Review code for security and performance
---

Review this code for:
- Security vulnerabilities
- Performance issues
- Code style violations
- Potential bugs
```

### Optimization
```markdown
---
description: Analyze and optimize code performance
---

Analyze this code for performance optimization:
- Algorithm complexity
- Memory usage
- Caching opportunities
```

## Commands with Arguments

### Fix Issue (All Arguments)
```markdown
---
description: Fix GitHub issue following coding standards
argument-hint: [issue-number] [additional-context]
---

Fix issue #$ARGUMENTS following our coding standards.
```

Usage: `/fix-issue 123 high-priority`

### PR Review (Positional Arguments)
```markdown
---
description: Review pull request
argument-hint: [pr-number] [priority]
---

Review PR #$1 with priority $2.

Focus on:
- Code quality
- Security
- Test coverage
```

Usage: `/pr-review 456 high`

### Create Component
```markdown
---
description: Create React component with tests
argument-hint: [component-name] [type]
---

Create React component: $1 (type: $2)

Include:
- TypeScript types
- Unit tests
- Storybook stories
```

Usage: `/component UserProfile functional`

## Commands with Bash Execution

### Git Commit
```markdown
---
description: Create conventional commit
allowed-tools: Bash(git:*)
---

**Status**: !\`git status --short\`
**Staged**: !\`git diff --cached\`
**Recent commits**: !\`git log --oneline -5\`

Create Conventional Commits format message based on staged changes.
```

### Project Status
```markdown
---
description: Show project status
allowed-tools: Bash(git:*), Bash(npm:*)
---

**Git**: !\`git status --short\`
**Branch**: !\`git branch --show-current\`
**Tests**: !\`npm test -- --listTests\`

Analyze and suggest next steps.
```

### Build Verification
```markdown
---
description: Verify build and tests
allowed-tools: Bash(pnpm:*)
---

**Build**: !\`pnpm build\`
**Tests**: !\`pnpm test\`

Report results and suggest fixes for failures.
```

## Commands with File References

### Compare Files
```markdown
---
description: Compare two files
argument-hint: [file1] [file2]
---

Compare @$1 with @$2:
- Key differences
- Which approach is better
- Migration steps needed
```

Usage: `/compare src/old-api.ts src/new-api.ts`

### Review Implementation
```markdown
---
description: Review implementation vs spec
argument-hint: [spec-file] [impl-file]
---

Review @$2 against spec in @$1.

Check:
- Requirement coverage
- Edge cases
- Error handling
```

Usage: `/review-impl docs/spec.md src/feature.ts`

## Git Workflow Commands

### Create Commit with Context
```markdown
---
description: Create commit with full context
allowed-tools: Bash(git:*)
---

**Changes**: !\`git diff HEAD\`
**Status**: !\`git status\`
**Branch**: !\`git branch --show-current\`

Create meaningful commit message in Conventional Commits format.
```

### Review Changes Before PR
```markdown
---
description: Review changes before creating PR
allowed-tools: Bash(git:*)
---

**Commits**: !\`git log origin/main..HEAD --oneline\`
**Diff**: !\`git diff origin/main...HEAD\`

Analyze changes and suggest:
- PR title
- PR description
- Areas needing attention
```

## Testing Commands

### Generate Unit Tests
```markdown
---
description: Generate comprehensive unit tests
argument-hint: [file-path]
---

Generate unit tests for @$1.

Include:
- Happy path
- Error cases
- Edge cases
- Mocked dependencies
```

Usage: `/test src/utils/validator.ts`

### Coverage Analysis
```markdown
---
description: Analyze test coverage
allowed-tools: Bash(npm:*)
---

**Coverage**: !\`npm test -- --coverage --silent\`

Identify:
- Uncovered critical paths
- Missing edge cases
- Suggested test additions
```

## Advanced: Hooks Example

### Deploy with Validation
```markdown
---
description: Deploy with pre-deploy validation
allowed-tools: Bash(git:*), Bash(npm:*)
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/pre-deploy-check.sh"
          once: true
---

**Branch**: !\`git branch --show-current\`
**Build**: !\`npm run build\`
**Tests**: !\`npm test\`

Deploy after all checks pass.
```

## Quick Templates

### Minimal
```markdown
Review this code for bugs and suggest improvements.
```

### With Description
```markdown
---
description: Quick code review
---

Review for bugs and improvements.
```

### With Arguments
```markdown
---
description: Process file
argument-hint: [file-path]
---

Process file: @$1
```

### With Bash
```markdown
---
description: Git status summary
allowed-tools: Bash(git:*)
---

Status: !\`git status\`
```

## Tips

- Start simple, add complexity as needed
- Test with various inputs
- Use `argument-hint` for better UX
- Scope `allowed-tools` appropriately
- Keep commands focused on one task
