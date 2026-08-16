# Skill mechanics

The skill-specific branch of `writing-for-agents`: what changes when the
document is a skill. Everything else about writing it is the universal
reference in `SKILL.md`; frontmatter keys and size limits are in this
marketplace's CLAUDE.md.

## Invocation

Two choices, trading the two loads:

- A model-invoked skill keeps a `description`, so the agent can fire it
  autonomously — and other skills can reach it. You can still type its name:
  model-invocation always includes user reach. The description is the
  skill's top-level context pointer, forced to stay loaded at all times —
  permanent context load in exchange for discoverability. A model-invoked
  skill whose content is all reference is also the home for reference that
  several skills share: they reach it by invoking the skill. Mechanics: omit
  `disable-model-invocation`, and write a model-facing `description` and
  `when_to_use` carrying the trigger branches (the pointer rules in
  `SKILL.md` apply in full).
- A user-invoked skill strips the description from the agent's reach: only
  the human typing its name can invoke it, and no other skill can. Zero
  context load, but it spends cognitive load — you are the index that must
  remember it exists. Mechanics: set `disable-model-invocation: true`; the
  `description` becomes human-facing — a one-line summary, trigger lists
  stripped, no `when_to_use`.
- A third mode, `user-invocable: false`, keeps a skill model-reachable but
  out of the `/` menu — background knowledge that is not a meaningful user
  action.

Pick model-invocation only when the agent must reach the skill on its own,
or another skill must. If it only ever fires by hand, make it user-invoked
and pay no context load.

Shared reference that two user-invoked skills both need can live in neither
— with no descriptions, neither can fire the other. Push it to a plain file
outside the skill system: external reference any skill can point at.

## Splitting by invocation

Split off a model-invoked skill when you have a distinct leading word that
should trigger it on its own — a trigger word you actually use in your
prompts — or another skill must reach it. You pay context load for the new
always-loaded description, so that independent reach has to be worth it.

## Router skills

When user-invoked skills multiply past what you can remember, that piled-up
cognitive load is cured by a router skill: one user-invoked skill that names
the others and when to reach for each, so the human has one skill to
remember instead of many. It can only hint, never fire them: user-invoked
skills have no description, so nothing but the human can reach them.
