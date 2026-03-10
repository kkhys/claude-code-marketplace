# Team Composition Patterns

## Cross-Layer Feature Development

Best for features that span multiple architectural layers with clear boundaries.

```text
Create an agent team to implement [feature].

Spawn 4 teammates:
- API layer: owns src/api/[feature]/, src/middleware/[feature]/
  Task: Define endpoints, request validation, response formatting
- Service layer: owns src/services/[feature]/, src/repositories/[feature]/
  Task: Business logic, data access, error handling
- UI layer: owns src/components/[feature]/, src/pages/[feature]/
  Task: Components, routing, state management
- Test layer: owns tests/
  Task: Unit tests for services, integration tests for API, component tests for UI

Dependencies:
- Test layer depends on API and Service layers stabilizing first
- UI layer depends on API layer defining endpoint contracts

Require plan approval. Have teammates message each other when they define
interfaces that others depend on.
```

**Why it works**: Each layer is independent enough for parallel work. The test teammate waits for APIs to stabilize, avoiding rework.

## Parallel Code Review

Best for thorough reviews where different perspectives catch different issues.

```text
Create an agent team to review PR #[number].

Spawn 3 reviewers:
- Security reviewer: Focus on authentication, authorization, input validation,
  injection risks, secret exposure, and OWASP top 10
- Performance reviewer: Focus on N+1 queries, unnecessary allocations,
  missing indexes, caching opportunities, and algorithmic complexity
- Architecture reviewer: Focus on code organization, separation of concerns,
  API design, error handling patterns, and test coverage

Each reviewer should:
1. Read all changed files
2. Write findings as a structured list with severity (critical/warning/suggestion)
3. Message the lead with findings

Do not use plan approval.
Synthesize all findings into a single review summary when done.
```

**Why it works**: Reviewers apply different lenses to the same code without overlapping. The lead synthesizes, avoiding duplicate comments.

## Hypothesis-Driven Debugging

Best for bugs where the root cause is unclear and multiple theories exist.

```text
Bug: [Detailed description with reproduction steps and error output]

Create an agent team with 4 investigators:
- Memory hypothesis: Check for memory leaks, unbounded caches, growing data structures
  in [relevant paths]
- Concurrency hypothesis: Check for race conditions, deadlocks, missing locks
  in [relevant paths]
- State hypothesis: Check for corrupted state, stale caches, incorrect initialization
  in [relevant paths]
- External hypothesis: Check for network timeouts, API changes, dependency updates
  in [relevant paths]

Rules:
- Each investigator must provide evidence (logs, code paths, reproduction) for their theory
- Actively try to disprove each other's hypotheses by messaging counterexamples
- When consensus emerges, the investigator with the correct theory implements the fix

No plan approval (investigation is read-heavy).
```

**Why it works**: Parallel investigation avoids anchoring bias. The adversarial structure ensures only well-evidenced theories survive.

## Module Migration

Best for migrating multiple independent modules to a new pattern or framework.

```text
Create an agent team to migrate [modules] from [old pattern] to [new pattern].

Reference implementation: [path to already-migrated module]

Spawn one teammate per module:
- Module A migrator: owns src/[moduleA]/, tests/[moduleA]/
- Module B migrator: owns src/[moduleB]/, tests/[moduleB]/
- Module C migrator: owns src/[moduleC]/, tests/[moduleC]/

Each teammate should:
1. Study the reference implementation
2. Plan the migration for their module
3. Implement the migration
4. Run module-specific tests
5. Verify no regressions

Require plan approval.
Do not modify shared utilities - if shared changes are needed, message the lead.
```

**Why it works**: Each module is self-contained, and the reference implementation provides a clear template. Teammates work without coordination overhead.

## Spike / Research Exploration

Best for exploring multiple technical approaches before committing to one.

```text
We need to decide between [approach A], [approach B], and [approach C]
for [problem description].

Create an agent team with 3 researchers:
- Approach A advocate: Build a proof-of-concept using [approach A].
  Focus on [specific concerns]. Document pros, cons, and effort estimate.
- Approach B advocate: Build a proof-of-concept using [approach B].
  Focus on [specific concerns]. Document pros, cons, and effort estimate.
- Approach C advocate: Build a proof-of-concept using [approach C].
  Focus on [specific concerns]. Document pros, cons, and effort estimate.

Each researcher works in their own directory: spike/[approach-name]/

After all complete:
- Have researchers review each other's implementations
- Each must identify weaknesses in the other approaches
- Lead synthesizes into a recommendation with trade-off analysis

No plan approval.
```

**Why it works**: Each advocate is motivated to make their approach look good, while the cross-review phase forces honest evaluation. The lead gets balanced input for the final decision.
