---
name: orchestrating-agent-team
description: Orchestrate agent teams for parallel implementation tasks. Use when the user requests agent teams, multi-teammate coordination, or parallel feature development across independent modules.
---

# Agent Team Orchestration Guide

## Decision: Teams vs Subagents

**Use agent teams when**:
- Teammates need to communicate with each other (share findings, challenge approaches)
- Work spans multiple independent modules or layers (frontend/backend/tests)
- Debugging requires competing hypotheses tested in parallel
- Tasks benefit from collaborative review and synthesis

**Use subagents instead when**:
- You only need the result, not inter-agent discussion
- Tasks are sequential or depend heavily on each other
- Same-file edits are required
- Token efficiency matters more than collaboration

**Rule of thumb**: If workers don't need to talk to each other, use subagents. If they do, use agent teams.

## Setup Check

Agent teams require the experimental flag. Before creating a team, verify it's enabled:

```
Check settings.json for:
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

If not enabled, inform the user and offer to add it to their settings.

## Team Composition Guidelines

### Size

- **3-5 teammates** for most tasks
- **5-6 tasks per teammate** keeps everyone productive
- Three focused teammates outperform five scattered ones

### File Ownership

**Critical**: Two teammates editing the same file causes overwrites. Always assign explicit file ownership:

```
Teammate A owns: src/auth/, tests/auth/
Teammate B owns: src/api/, tests/api/
Teammate C owns: src/ui/, tests/ui/
```

Never allow overlapping file ownership. If shared files need changes, assign one teammate as the sole editor and have others communicate required changes via messages.

## Implementation Workflow

### Phase 1: Plan

1. Analyze the task and identify independent work units
2. Define team structure with clear roles and file ownership
3. Create the team with plan approval required:

```text
Create an agent team for [task description]. Spawn [N] teammates:
- [Role A]: owns [files/modules]. Responsible for [scope].
- [Role B]: owns [files/modules]. Responsible for [scope].
- [Role C]: owns [files/modules]. Responsible for [scope].
Require plan approval before any teammate makes changes.
```

### Phase 2: Review Plans

The lead reviews each teammate's plan before approving:

- Verify no file ownership conflicts
- Check that the approach aligns with project conventions
- Reject plans that modify shared files without coordination
- Reject plans lacking test coverage (if applicable)

Give the lead explicit criteria:

```text
Only approve plans that:
- Stay within the teammate's assigned file ownership
- Include test files for new functionality
- Follow existing code patterns in the codebase
```

### Phase 3: Implement

After plan approval, teammates implement independently. Key instructions for the lead:

```text
Wait for all teammates to complete their tasks before proceeding.
Do not implement tasks yourself - delegate everything to teammates.
If a teammate gets stuck, provide guidance via message rather than taking over.
```

### Phase 4: Integrate

After all teammates finish:

1. Lead reviews all changes for consistency
2. Run full test suite
3. Resolve any integration issues (assign to one teammate)
4. Clean up the team

## Prompt Templates

### New Feature Development

```text
Create an agent team to implement [feature name].

Context: [Brief description of the feature and its requirements]

Spawn 3 teammates:
- Backend developer: owns src/api/[module]/, src/services/[module]/, tests/api/[module]/
  Task: Implement API endpoints and business logic
- Frontend developer: owns src/components/[module]/, src/hooks/[module]/, tests/components/[module]/
  Task: Build UI components and state management
- Test engineer: owns tests/integration/[module]/, tests/e2e/[module]/
  Task: Write integration and e2e tests (wait for backend/frontend APIs to stabilize)

Require plan approval.
Wait for all teammates before synthesizing results.
```

### Parallel Refactoring

```text
Create an agent team to refactor [description].

Spawn [N] teammates, one per module:
- [Module A] specialist: owns [paths]. Refactor [specific changes].
- [Module B] specialist: owns [paths]. Refactor [specific changes].
- [Module C] specialist: owns [paths]. Refactor [specific changes].

Constraints:
- All changes must be backward-compatible
- Each teammate must run tests for their module before marking complete
- Do not modify shared interfaces without messaging all teammates first

Require plan approval.
```

### Debugging with Competing Hypotheses

```text
Bug: [Description of the issue with reproduction steps]

Create an agent team to investigate. Spawn 3-4 teammates, each testing a
different hypothesis:
- Hypothesis A: [theory]. Investigate [specific areas].
- Hypothesis B: [theory]. Investigate [specific areas].
- Hypothesis C: [theory]. Investigate [specific areas].

Have teammates challenge each other's findings. When consensus emerges,
the teammate with the correct hypothesis implements the fix.

No plan approval needed (read-heavy work).
```

See [patterns.md](references/patterns.md) for more team composition patterns.

## Common Pitfalls

### Lead implements instead of delegating

The lead sometimes starts coding instead of waiting. Always include:
```text
Wait for your teammates to complete their tasks before proceeding.
Do not implement any tasks yourself.
```

### File conflicts

Two teammates editing the same file silently overwrites changes. Prevention:
- Declare file ownership explicitly in the spawn prompt
- Include "Do not modify files outside your assigned scope" in instructions
- Use plan approval to catch ownership violations before implementation

### Over-sized teams

More teammates = more tokens, more coordination overhead. Start small:
- 3 teammates for most tasks
- Add more only if work is genuinely parallelizable
- Each teammate should have meaningful, independent work

### Missing cleanup

Always clean up after the team finishes:
```text
Clean up the team
```
Shut down all teammates before cleanup. Only the lead should run cleanup.

### Stale task status

Teammates sometimes forget to mark tasks complete. If tasks appear stuck:
- Check if the work is actually done
- Tell the lead to nudge the teammate
- Manually update task status if needed

## Quality Gates

Use hooks to enforce standards when teammates complete work. See [quality-gates.md](references/quality-gates.md) for configuration.

Key hooks:
- `TeammateIdle`: Run checks when a teammate finishes (exit code 2 to send feedback)
- `TaskCompleted`: Validate task output before marking complete (exit code 2 to block)

## Limitations

- **Experimental**: Feature may change or break
- **No session resumption**: `/resume` does not restore in-process teammates
- **One team per session**: Clean up before starting a new team
- **No nested teams**: Teammates cannot spawn their own teams
- **Lead is fixed**: Cannot transfer leadership
- **Split panes**: Require tmux or iTerm2 (in-process mode works anywhere)
