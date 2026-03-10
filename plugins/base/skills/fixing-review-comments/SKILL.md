---
name: fixing-review-comments
description: Addresses unresolved review comments on the current branch. Use when the user wants to fix review feedback, address PR review points, or resolve review comments.
---

# Fix Review Comments

Address all unresolved review comments on the current branch by reading feedback, implementing fixes, and resolving threads.

## Workflow

### Step 1: Read Unresolved Review Comments

Invoke the `reading-unresolved-pr-comments` skill to fetch all unresolved review threads and generate a fix plan.

Review the plan output to understand:
- Each review comment's intent and requested change
- File paths and line numbers involved
- Dependencies between fixes
- Which fixes can be parallelized

### Step 2: Implement Fixes

Execute each fix task using `base:general-purpose-assistant` subagents:

- **One subagent per fix task** - each task gets its own subagent invocation
- **Parallel execution** - launch independent tasks simultaneously (tasks with no file overlap or dependency)
- **Sequential execution** - tasks that depend on each other or modify the same file must run in order
- Provide each subagent with clear context: the review comment, file path, line number, and required change

### Step 3: Verify Changes

After all fixes are implemented, use a `base:general-purpose-assistant` subagent to run tests and lint:

```
Run the project's test suite and linter to verify all changes pass.
```

- If any test or lint check fails, use additional `base:general-purpose-assistant` subagents to fix the issues
- Repeat until all checks pass

### Step 4: Commit and Push

Invoke the `formatting-commit` skill to commit changes with an appropriate Conventional Commits message.

Then push the changes:

```bash
git push --force-with-lease
```

### Step 5: Reply to Review Comments

For each unresolved review thread, post a reply in Japanese that includes:
- A brief description of what was fixed
- The commit URL that addresses the feedback

Get the latest commit URL:

```bash
gh api repos/{owner}/{repo}/commits/$(git rev-parse HEAD) --jq '.html_url'
```

Then reply to each thread using the thread ID from Step 1:

```bash
gh api graphql -f query='
  mutation ($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(
      input: { pullRequestReviewThreadId: $threadId, body: $body }
    ) {
      comment { id }
    }
  }' \
  -f threadId="<THREAD_ID>" \
  -f body="$REPLY_BODY"
```

Reply format example: `<COMMIT_URL> で修正しました。[具体的な修正内容の説明]`

### Step 6: Resolve Review Comments

Before resolving any review threads, confirm with the user whether they want threads to be resolved now (and which ones, if not all).
If and only if the user explicitly requests it, invoke the `resolving-pr-comments` skill to resolve the specified review threads on the PR.

### Step 7: Update PR Description

Update the PR description to reflect the latest state of the implementation:

```bash
gh pr view --json number -q '.number'
```

Use the PR number to update the description with a summary of all changes made, including the review comment fixes.

## Important Rules

- **Complete all fixes** before committing - do not commit partial work
- **Run verification** (Step 3) before committing - never push broken code
- **Force-with-lease** for push - the branch likely has existing commits
- **Do not skip steps** - each step is essential for a clean review cycle
