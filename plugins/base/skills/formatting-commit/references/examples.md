# High Quality Commit - Examples and Reference

This document provides detailed examples, best practices, and troubleshooting for high-quality commit creation.

## Table of Contents

- [Detailed Examples](#detailed-examples)
  - [Example 1: Initial Implementation Commit](#example-1-initial-implementation-commit)
  - [Example 2: Addressing Review Feedback (Squash)](#example-2-addressing-review-feedback-squash)
  - [Example 3: Independent Feature Addition (New Commit)](#example-3-independent-feature-addition-new-commit)
  - [Example 4: Organizing WIP Commits (Interactive Rebase)](#example-4-organizing-wip-commits-interactive-rebase)
  - [Example 5: Incremental Feature Implementation](#example-5-incremental-feature-implementation)
  - [Example 6: Bug Fix with Tests](#example-6-bug-fix-with-tests)
- [Commit Strategy Details](#commit-strategy-details)
- [Commit Message Best Practices](#commit-message-best-practices)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)

## Detailed Examples

### Example 1: Initial Implementation Commit

**Scenario**: Implementing "Task Management" feature for the first time

**Steps**:

```bash
# 1. Check branch status
git status
# On branch feature/task-management
# Changes not staged for commit:
#   modified:   src/views/TaskList.tsx
#   modified:   src/services/tasks.ts
#   new file:   src/components/TaskCreateForm.tsx

git log --oneline --graph origin/main..HEAD
# (no commits yet on this branch)

# 2. Strategy decision: First commit on branch → New commit

# 3. Execute commit
git add -A
git commit
```

**Commit Message**:

```
feat: add task management feature

Implement task creation and listing functionality:
- Add TaskCreateForm component with validation
- Add POST /api/tasks endpoint
- Integrate form with existing TaskList view

Users can now create and view tasks with due dates.

Closes #789
```

### Example 2: Addressing Review Feedback (Squash)

**Scenario**: After PR creation, received feedback to "add input sanitization for security"

**Steps**:

```bash
# 1. Check current commits
git log --oneline --graph origin/main..HEAD
# * b3c4d5e feat: add task management feature

# 2. Fix the issue
# Edit src/components/TaskCreateForm.tsx...

# 3. Strategy decision: Same theme as existing commit → Squash

# 4. Merge into existing commit
git add -A
git commit --amend
```

**Updated Commit Message**:

```
feat: add task management feature

Implement task creation and listing functionality:
- Add TaskCreateForm component with enhanced security
- Add POST /api/tasks endpoint
- Integrate form with existing TaskList view

Security improvements:
- Input sanitization for XSS prevention
- Title length validation (1-200 chars)
- Description content filtering

Users can now create and view tasks with due dates.

Closes #789
```

```bash
# 5. Force push (update PR)
git push --force-with-lease
```

### Example 3: Independent Feature Addition (New Commit)

**Scenario**: After implementing task management, separately adding "Notification System"

**Steps**:

```bash
# 1. Check current commits
git log --oneline --graph origin/main..HEAD
# * b3c4d5e feat: add task management feature

# 2. Implement notification system
# ...

# 3. Strategy decision: Independent from existing commit → New commit

# 4. Create new commit
git add -A
git commit
```

**Commit Message**:

```
feat: add notification system

Implement real-time notification functionality:
- Add notification service with WebSocket
- Add POST /api/notifications endpoint
- Add notification bell icon with counter
- Store notifications in local cache

Supports task updates, mentions, and deadline alerts.

Closes #812
```

```bash
# 5. Verify result
git log --oneline --graph origin/main..HEAD
# * f7g8h9i feat: add notification system
# * b3c4d5e feat: add task management feature
```

### Example 4: Organizing WIP Commits (Interactive Rebase)

**Scenario**: Created many small commits during development. Want to organize before PR.

**Current Commit History**:

```bash
git log --oneline --graph origin/main..HEAD
# * k9l0m1n WIP: fix styling
# * h6i7j8k WIP: add sorting
# * e3f4g5h feat: add dashboard component
# * b0c1d2e WIP: try different layout
# * y8z9a0b feat: add chart model
# * v5w6x7y fix: data type
```

**Steps**:

```bash
# 1. Start interactive rebase
git rebase -i origin/main

# 2. Editor opens
```

**Editor Changes**:

Before:
```
pick y8z9a0b feat: add chart model
pick v5w6x7y fix: data type
pick b0c1d2e WIP: try different layout
pick e3f4g5h feat: add dashboard component
pick h6i7j8k WIP: add sorting
pick k9l0m1n WIP: fix styling
```

After:
```
pick y8z9a0b feat: add chart model
squash v5w6x7y fix: data type
drop b0c1d2e WIP: try different layout
pick e3f4g5h feat: add dashboard component
squash h6i7j8k WIP: add sorting
squash k9l0m1n WIP: fix styling
```

**Edit Commit Messages**:

**First commit:**
```
feat: add data visualization model

Define chart data structure with TypeScript:
- Chart interface with configuration options
- Data transformation utilities
- Type-safe rendering methods

Supports bar, line, and pie chart types.
```

**Second commit:**
```
feat: add analytics dashboard

Implement dashboard UI component:
- Widget grid layout with responsive design
- Interactive chart rendering
- Real-time data updates

Users can visualize project metrics with customizable charts.
```

**Result**:

```bash
git log --oneline --graph origin/main..HEAD
# * p3q4r5s feat: add analytics dashboard
# * m0n1o2p feat: add data visualization model

# Clean history achieved!
```

### Example 5: Incremental Feature Implementation

**Scenario**: Implementing large "Search Functionality" feature incrementally (Model → API → UI)

**Step 1: Model Implementation**

```bash
# Implementation...

git add src/models/
git commit -m "feat: add search model

Define search data structures:
- Query interface with filter options
- SearchResult type definitions
- Pagination utilities

Provides type-safe search operations."

git push
```

**Step 2: API Implementation**

```bash
# Implementation...

git add src/api/search.ts
git commit -m "feat: add search API endpoints

Implement search REST API:
- GET /api/search - Execute search query
- GET /api/search/suggest - Get autocomplete suggestions
- POST /api/search/history - Save search history
- GET /api/search/filters - Get available filters

Uses full-text indexing for fast search results."

git push
```

**Step 3: UI Implementation**

```bash
# Implementation...

git add src/components/search/
git commit -m "feat: add search UI components

Implement search user interface:
- SearchBar component with autocomplete
- Filter panel with dynamic options
- Result list with pagination
- Search history dropdown

Provides comprehensive search experience."

git push
```

**Final History**:

```bash
git log --oneline --graph origin/main..HEAD
# * t6u7v8w feat: add search UI components
# * q3r4s5t feat: add search API endpoints
# * n0p1q2r feat: add search model

# Each commit is independently reviewable
# Each commit can be built and tested independently
```

### Example 6: Bug Fix with Tests

**Scenario**: Found bug in URL validation, fixing and adding tests

**Steps**:

```bash
# 1. Check current work
git status
# On branch fix/url-validation

# 2. Fix bug and add tests
# Modified src/utils/validators.ts
# Added src/utils/validators.test.ts

# 3. Commit
git add -A
git commit
```

**Commit Message**:

```
fix: correct URL validation for special characters

Fix URL validation to properly handle query parameters and fragments.
Previously, URLs with encoded characters were incorrectly rejected.

Changes:
- Update validation regex to support URL encoding
- Add comprehensive test cases for edge cases

Closes #921
```

## Commit Strategy Details

### Squash Strategy (Default)

**When to use:**
- Continuously developing with repeated feature additions or bug fixes
- Addressing review feedback or making adjustments
- Grouping multiple related changes into one

**Benefits:**
- Clean branch commit history
- Easy to review as single logical change
- Organized history when PR is merged

**Execution:**

```bash
# Stage changes
git add -A

# Merge into previous commit (edit message)
git commit --amend

# Or merge without changing message
git commit --amend --no-edit
```

**Notes:**
- Force push required after amending pushed commits
- In team development, verify no one is based on that commit

### New Commit Strategy

**When to use:**
- Adding clearly different features or fixes
- Splitting commits improves history understanding
- Each commit can be independently built and tested

**Benefits:**
- Detailed change history
- Easy problem tracking with git bisect
- Can revert specific changes

**Execution:**

```bash
# Stage changes
git add -A

# Create new commit
git commit -m "feat: add real-time sync

Implement real-time data synchronization:
- Add WebSocket connection manager
- Add conflict resolution logic
- Add offline queue handling

Closes #567"
```

### Interactive Rebase Strategy

**When to use:**
- Want to organize commit history before PR
- Want to logically group small commits
- Want to change commit order
- Want to remove unnecessary commits (WIP, fixup, etc.)

**Benefits:**
- Create clean, meaningful commit history
- Easier for reviewers to understand
- Organized main branch history

**Execution:**

```bash
# Interactive rebase with diff from main
git rebase -i origin/main

# Or rebase last N commits
git rebase -i HEAD~3
```

**Editor operations:**

```
pick abc1234 feat: add data model
pick def5678 fix: typo in model
pick ghi9012 feat: add controller
pick jkl3456 fix: validation

# ↓ Edit as follows

pick abc1234 feat: add data model
squash def5678 fix: typo in model
pick ghi9012 feat: add controller
squash jkl3456 fix: validation
```

Result: Merged into 2 logical commits

## Commit Message Best Practices

### Good Commit Message Examples

```
feat: add export functionality

Allow users to export data in multiple formats:
- CSV export with custom column selection
- JSON export with nested structures
- PDF export with formatted tables
- Excel export with multiple sheets

Implemented with streaming for large datasets.

Closes #445
```

### Bad Commit Message Examples

```
# Bad example 1: Unclear
update stuff

# Bad example 2: Too detailed implementation
Changed DataService.ts line 67 to use Promise.all instead of sequential awaits

# Bad example 3: Multiple unrelated changes
Fix memory leak and add caching and update dependencies
```

### Type Selection Guide

- **feat**: User-visible new feature
- **fix**: User-affecting bug fix
- **refactor**: Code improvement without behavior change
- **perf**: Performance improvement
- **test**: Test addition/modification
- **docs**: Documentation-only changes
- **style**: Code formatting, semicolons, etc.
- **chore**: Build, dependency updates, etc.

## Common Scenarios

### Scenario 1: Addressing Review Feedback

**Situation:** PR has review comments, fixes needed

**Recommended strategy:** Squash

```bash
# Make fixes
# ...

# Merge into existing commit
git add -A
git commit --amend

# Force push (update PR)
git push --force-with-lease
```

### Scenario 2: Incremental Implementation of Large Feature

**Situation:** Implementing large feature in multiple steps

**Recommended strategy:** New commit (per step)

```bash
# Step 1: Create foundation
git add src/core/
git commit -m "feat: add core infrastructure"

# Step 2: Implement business logic
git add src/services/
git commit -m "feat: add business logic layer"

# Step 3: Implement presentation
git add src/components/
git commit -m "feat: add UI components"
```

### Scenario 3: Organizing WIP Commits

**Situation:** Created many WIP commits during development

**Recommended strategy:** Interactive Rebase

```bash
# Check WIP commits
git log --oneline

# Organize with interactive rebase
git rebase -i origin/main

# In editor, change unnecessary commits to squash/fixup
# Keep only meaningful commits
```

## Troubleshooting

### Problem: Cannot push amended commit

**Cause:** Remote history differs

**Solution:**

```bash
# Safe force push
git push --force-with-lease
```

### Problem: Conflict during rebase

**Solution:**

```bash
# Resolve conflict
# Edit files...

# Continue rebase after resolution
git add .
git rebase --continue

# Or abort
git rebase --abort
```

### Problem: Accidentally amended wrong commit

**Solution:**

```bash
# Check previous state with reflog
git reflog

# Return to previous commit
git reset --hard HEAD@{1}
```

## Summary

Two principles for high-quality commits:

1. **Choose appropriate strategy**: Squash (default), new commit (independent changes), Rebase (organize history)
2. **Clear messages**: Describe why the change was necessary

Following these improves team development efficiency and future maintainability.
