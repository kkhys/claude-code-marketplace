# Team Composition Patterns

## Cross-Layer Feature Development

**When**: A feature spans multiple architectural layers (API, service, UI, tests) with clear boundaries.

Spawn one teammate per layer. The test layer teammate should wait for API and service layers to stabilize before writing integration tests. Have teammates message each other when defining interfaces that others depend on.

**Why it works**: Each layer is independent enough for parallel work. The key insight is that test teammates should not start immediately — waiting for interfaces to settle avoids costly rework.

**Watch for**: Shared type definitions or utility files that multiple layers import. Assign one teammate to own these exclusively.

## Parallel Code Review

**When**: A PR needs thorough review from multiple specialized perspectives (security, performance, architecture).

Spawn 3 reviewers, each with a distinct lens. All read the same changed files but analyze from different angles. No plan approval needed — review is read-only. The lead synthesizes findings into a single coherent review.

**Why it works**: Different reviewers catch different classes of issues without redundant overlap. The lead's synthesis avoids duplicate or contradictory comments on the PR.

**Watch for**: Reviewers tend to drift outside their lane. Give each a specific focus area and explicitly tell them to stay within it.

## Competing-Hypothesis Debugging

**When**: A bug's root cause is unclear and multiple plausible theories exist.

Spawn one investigator per hypothesis. Each gathers evidence for their theory and actively tries to disprove others via messages. No plan approval needed (investigation is read-heavy). When consensus emerges, the investigator with the correct theory implements the fix.

**Why it works**: Parallel investigation avoids anchoring bias. The adversarial structure — teammates challenging each other — ensures only well-evidenced theories survive rather than the first plausible explanation.

**Watch for**: Investigators get tunnel-visioned on confirming their hypothesis. Encourage them to genuinely try to disprove their own theory, not just confirm it.

## Module Migration

**When**: Migrating multiple independent modules to a new pattern or framework, with an existing reference implementation to follow.

Spawn one teammate per module. All study the reference implementation first, then migrate their assigned module independently. Communication overhead is near zero because everyone follows the same template.

**Why it works**: Modules are self-contained and the reference provides a shared contract, eliminating the need for cross-teammate coordination.

**Watch for**: Shared utilities that multiple modules depend on. If the migration changes a shared utility, assign it to one teammate and have them complete it before others start their modules.

## Spike / Research Exploration

**When**: Evaluating multiple technical approaches before committing to one.

Spawn one advocate per approach, each building a proof-of-concept in their own directory (e.g., `spike/approach-a/`). After completion, have advocates cross-review each other's work and identify weaknesses. The lead synthesizes into a recommendation with tradeoff analysis.

**Why it works**: Each advocate is motivated to produce the best version of their approach. Cross-review forces honest evaluation because each advocate knows the others will scrutinize their work.

**Watch for**: Advocates naturally downplay weaknesses in their own approach. Explicitly ask each to name the biggest risk and the scenario where their approach would fail.
