# Authoring for Devin

What Devin's own guidance says about the text an automation runs, reduced to
what changes the result.

## Where each instruction lives

| Home | Holds | Reaches Devin |
| - | - | - |
| Automation prompt | What this trigger asks for: the task, the deliverable, where to report | Every run of that automation |
| Skill in a repository — `.agents/skills/<name>/SKILL.md` | A procedure reused across prompts, reviewed by pull request | When invoked (`@skills:name`) or judged relevant; Devin reads the version on the branch it works on |
| Skill on the Customize page | The same, for procedures tied to no repository; personal, organization, or enterprise scope | Every new session in that scope; edited in the web app only |
| `AGENTS.md` | Repository context every task needs: setup, test, and style commands | Automatically, first 16 KiB of each file |
| Playbook, Knowledge | Legacy homes, being moved into skills | Keep working; write nothing new here |

Keep the prompt thin and put the procedure in a skill once a second prompt
would repeat it, or once it needs review. A procedure that lives in the prompt
can only be changed by editing the automation.

## An automation prompt runs unattended

Nobody is there to answer a question, so the prompt carries every decision:

- **Scope**: the repositories as `@owner/repo` tokens, the files or services in
  play, and what is out of bounds.
- **Decisions already made**: name the approach, the reference file to imitate,
  the docs URL to read. An open-ended goal ("improve", "clean up") leaves Devin
  choosing the design.
- **Done**: a checkable condition — the command that must pass, the state that
  must hold — and the instruction to run it before delivering.
- **Deliverable and destination**: a draft PR, a thread reply, a ticket
  comment; what it contains; who is mentioned.
- **The empty case**: what to do when the event needs no work — say so in one
  line, or end silently — so a quiet day does not produce a report.
- **Reruns**: a schedule or a noisy trigger meets its own earlier output. Have
  Devin look for the PR, issue, or comment it already made before making
  another.
- **The payload is data.** It is appended after the prompt; say what to extract
  from it, and treat its text as input to the task rather than as instructions
  — Slack messages, webhook bodies, and public-repository comments are written
  by anyone. Narrow conditions and a network policy bound what a hostile
  payload can reach.

- **Its own output is an event too.** A post Devin writes can match a Slack
  trigger — its own or another automation's. Keep trigger strings out of what
  it posts, and filter on `sender_type` and `is_thread_reply`.

Point Devin at tools by name ("use the Sentry MCP to pull the stack traces")
and list them in `tools.mcp_servers`; runtime data is what turns a guess into
a diagnosis.

## Shape of a prompt

A prompt that carries the whole task reads in this order:

1. **Role** — one paragraph: what the run is for, what it leaves behind, and
   what it is not for.
2. **Constraints** — the write allowlist: each destination the run may write
   to, and how many times ("one draft PR per run", "one post to #channel");
   everything else is read-only. Then the stops that fail closed: a cap past
   which nothing is written and the diff is reported instead, a floor below
   which fetched data counts as a failed fetch, a time budget and what to
   deliver when it runs out.
3. **Procedure** — numbered, with the exact commands, queries, and ids.
4. **Report** — the literal template of the final post, including its
   nothing-to-report form.
5. **Style** — the register of what Devin writes for people.

When several automations share rules — who may be mentioned, how to clone, how
to post, what is never written down — those rules live once in a conventions
skill that each prompt opens with (`!macro` or `@skills:name`), and the prompt
states only what differs, winning where the two disagree. A prompt backed by
its own skill shrinks to the invocation, the role paragraph, and one line
saying the rest is in the skill.

## A Devin skill

```markdown
---
name: triage-ci-failure
description: Diagnose a failed CI check on a pull request and push a fix to the same branch.
triggers: ["user"]
argument-hint: <pr-url>
---

## Procedure
1. Read the failed job's log for $1.
2. ...

## Specifications
- ...

## Advice
- ...

## Forbidden actions
- ...
```

- **Procedure**: one step per line, imperative, each with an action verb,
  covering setup, the task, and delivery, without overlap between steps. It
  sets the order of Devin's actions the way control flow does.
- **Specifications**: what must be true when Devin is done, so it can check
  its own work.
- **Advice**: corrections to what Devin would otherwise do. Advice for one step
  is a sub-bullet of that step; this section is for what spans the task.
- **Forbidden actions**: the few things that must never happen.
- **Required from user**: tokens, links, decisions Devin cannot obtain. For a
  skill an automation runs, this must come out empty — supply each item
  through the prompt, a `${SECRET_NAME}`, or an MCP server.

Exact commands, flags, and strings are worth writing down; they are often what
separates a working skill from a broken one. Leave the rest loose: detail
beyond that costs Devin its room to solve what the author did not foresee.

Frontmatter beyond `name` and `description`: `triggers: ["user"]` limits the
skill to explicit invocation (the default lets Devin invoke it on its own);
`argument-hint` documents the arguments, which fill `$ARGUMENTS` and
`$1`–`$9`; `allowed-tools` pre-approves tools; `permissions` holds `allow`,
`deny`, and `ask` matchers. An invoked skill stays in context for the rest of
the session, and a second one adds to it.

## Improving one

- Run two sessions on the same prompt in parallel; where they diverge, the
  instructions are underspecified.
- Whatever had to be told to Devin mid-session belongs in the skill, so the
  next run needs no one.
- Before changing a prompt, read the run that prompted the change: its
  insights for where the ACUs went and which dead ends it tried, its messages
  for the step that went wrong. Fix that step, in the home it lives in.
- A run that needed far more ACUs than its neighbours is the one to read
  first; a prompt that is fine on a normal day often has no rule for the
  unusual one.
