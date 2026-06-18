---
name: orchestrating-agent-team
description: Orchestrate agent teams for parallel implementation tasks. Use when the user requests agent teams, multi-teammate coordination, or parallel feature development across independent modules. Also use when the user mentions 'spawn teammates', 'create a team', 'work in parallel', 'multi-agent', or describes tasks spanning multiple independent modules (frontend/backend/tests) that could benefit from simultaneous development, concurrent code review, or competing-hypothesis debugging.
context: fork
disable-model-invocation: true
---

# Agent Team Orchestration

Agent teams run multiple Claude Code sessions in parallel on the same codebase. Each teammate operates as an independent process with its own context window, communicating through a shared mailbox and task list. The lead (you) creates the team, assigns work, reviews plans, and integrates results — but does not implement anything directly.

## Teams vs Subagents

The deciding factor is whether workers need to talk to each other.

| | Agent Teams | Subagents (Agent tool) |
|---|---|---|
| Communication | Teammates message each other directly | Report only to the caller |
| Context | Each has its own context window | Runs inside caller's context |
| Coordination | Shared task list, peer-to-peer | Caller manages everything |
| Cost | Higher (independent instances) | Lower (result summaries) |
| Best for | Collaborative, multi-module work | Independent, result-oriented tasks |

Use teams when teammates need to agree on interfaces, challenge each other's approaches, or coordinate across modules. Use subagents when you just need results collected back to you.

## Prerequisites

Agent teams require an experimental flag. Verify in settings.json before creating a team:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

If not enabled, offer to add it to the user's settings before proceeding.

## How Teams Work

### Lifecycle

1. **Create** — TeamCreate spins up the team and defines teammates with roles
2. **Plan** — Each teammate explores and submits a plan (if plan approval is required)
3. **Execute** — Teammates implement independently, messaging as needed
4. **Integrate** — Lead reviews all changes, runs tests, resolves conflicts
5. **Cleanup** — Shut down teammates and clean up the team

### Communication

- **Direct message**: Send to a specific teammate by name
- **Broadcast**: Send to all teammates simultaneously
- **Task list**: Shared view of pending / in-progress / completed tasks

Peer-to-peer messaging is what makes teams fundamentally different from subagents. Teammates can share discoveries, warn about edge cases, or agree on interface contracts without the lead mediating every exchange.

### Display Modes

- **In-process** (default): All teammates in the main terminal. Shift+Down cycles between them. Works in any terminal.
- **Split panes**: Each teammate in its own pane for simultaneous visibility. Requires tmux or iTerm2.

## Designing Team Work

### File Ownership Is Non-Negotiable

Two teammates editing the same file causes silent overwrites — the second save destroys the first teammate's work with no warning or merge. This is the most common and most costly failure mode.

Every teammate must own distinct files. Declare ownership explicitly in the spawn prompt:

```
Backend dev: owns src/api/auth/, src/services/auth/, tests/api/auth/
Frontend dev: owns src/components/auth/, src/hooks/auth/
Test engineer: owns tests/integration/auth/, tests/e2e/auth/
```

If a shared file needs changes (config, type definitions, interfaces), assign exactly one teammate as sole editor. Others communicate their required changes via messages.

### Team Size

3-5 teammates for most tasks. Three focused teammates consistently outperform five scattered ones because:

- Coordination overhead grows with each addition
- Token costs scale linearly per teammate
- Tasks become trivially thin below 3 per teammate

Aim for 5-6 tasks per teammate. If each teammate has fewer than 3 substantive tasks, reduce the team size.

### Task Decomposition

Follow the codebase's natural boundaries — modules, layers, packages. Each work unit should be:

- **Independent**: Completable without blocking on others
- **Testable**: Has clear verification criteria
- **Scoped**: Fits within one teammate's context

When dependencies exist (e.g., frontend needs backend API contracts), have the upstream teammate message downstream when interfaces stabilize rather than making downstream wait entirely.

## Running a Team Session

### Phase 1: Analyze and Spawn

Identify independent work units, then create the team with explicit roles and file ownership:

```
Create an agent team to implement [feature].
Spawn N teammates:
- [Role]: owns [files]. Responsible for [scope].
- [Role]: owns [files]. Responsible for [scope].
Require plan approval before making changes.
```

Require plan approval for work that modifies production code. Skip it for read-heavy tasks (reviews, investigations, research) where uncoordinated changes are not a risk.

### Phase 2: Review Plans

When a teammate submits a plan, verify:

- No file ownership conflicts with other teammates
- Approach aligns with project conventions (check CLAUDE.md)
- Test coverage included for new functionality
- No modifications to shared files without coordination

Reject plans that violate these and provide specific feedback on what to fix.

### Phase 3: Monitor Execution

The lead's role during execution is coordination, not implementation.

- **Do not implement anything yourself.** Delegate all work to teammates.
- **Wait for all teammates to complete** before moving to integration.
- If a teammate gets stuck, send guidance via message rather than taking over.

This is the hardest discipline. The natural instinct is to help by coding, but doing so breaks the parallel model and risks file conflicts. A lead who implements is a lead who creates merge conflicts.

### Phase 4: Integrate and Verify

1. Review all changes for cross-module consistency
2. Run the full test suite
3. If integration issues arise, assign them to one specific teammate — do not fix them yourself
4. Clean up the team when done

Always clean up explicitly — teams consume resources until shut down.

## What Goes Wrong

### Lead implements instead of delegating

The most frequent anti-pattern. The lead starts writing code instead of coordinating. Always include these instructions when spawning:

```
Do not implement any tasks yourself.
Wait for all teammates to complete their tasks before proceeding.
If a teammate gets stuck, send them guidance rather than taking over.
```

### Silent file overwrites

Two teammates editing the same file produces no error and no merge — just data loss. The second save silently destroys the first. Prevention:

- Declare file ownership in the spawn prompt
- Include "Do not modify files outside your assigned scope" per teammate
- Use plan approval to catch ownership violations before implementation begins

### Over-sized teams

More teammates does not mean faster results. Signs you have too many:

- Teammates idle-waiting with nothing substantive to do
- Tasks are trivial (single-file, single-function changes)
- Communication overhead exceeds productive work time

### Forgotten cleanup

Teams persist until explicitly cleaned up. Always run cleanup when done, even if something went wrong. Only the lead should run cleanup, and all teammates should be shut down first.

### Stale task status

Teammates sometimes forget to mark tasks complete. If progress appears stuck, check whether the work is actually done and nudge the teammate or update status manually.

## Quality Gate Hooks

Hooks automate quality checks when teammates finish work:

- **TeammateIdle**: Fires when a teammate is about to go idle. Exit code 2 sends feedback and keeps the teammate working. Use for running tests or lint checks before sign-off.
- **TaskCompleted**: Fires when a task is marked complete. Exit code 2 blocks completion. Use for validating deliverables meet acceptance criteria.
- **WorktreeCreate**: Fires on worktree creation. Enables per-teammate file isolation, eliminating conflict risk entirely.

Configure in `.claude/settings.json` (project) or `~/.claude/settings.json` (user). Hook scripts receive teammate/task context as JSON on stdin.

## Limitations

- **Experimental**: Feature may change between versions
- **No session resumption**: `/resume` does not restore in-process teammates
- **One team per session**: Clean up before starting a new team
- **No nested teams**: Teammates cannot create their own teams
- **Lead is fixed**: Cannot transfer leadership mid-session
- **Split panes**: Require tmux or iTerm2; in-process mode works anywhere

## Team Patterns

See [patterns.md](references/patterns.md) for team composition patterns covering feature development, code review, debugging, migration, and research spikes.
