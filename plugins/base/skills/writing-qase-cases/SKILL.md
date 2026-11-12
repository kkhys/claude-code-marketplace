---
name: writing-qase-cases
description: >-
  Rules for what a Qase test case holds: only what lasts as long as the
  behaviour, variants as parameters (single, group, shared), and where the
  PR, the ticket, a feature flag and the environment go instead.
when_to_use: >-
  Always consult before creating or editing a Qase test case, through the
  API or a Qase MCP tool — "Qase にケースを追加して", "テストケースを直して",
  "パラメータにして" — and when judging whether an existing case is well
  written.
---

# Writing Qase Cases

A case outlives the PR that prompted it, so it holds only what is durable:
what stays true for as long as the behaviour exists. Everything tied to a
moment has another home.

| It is about | Home |
| - | - |
| The behaviour: an action and what a person then sees | The case |
| Variants of one behaviour: a display mode, a language, a role, an input with its outcome | The case's parameters |
| Setup that several cases repeat | A shared step (`GET /shared_step/<CODE>`) |
| The PR, the ticket, why the case was added | The run: its title, description and tags |
| A feature flag and its state, the environment, the account, the test data used | The run's description and the result's `comment` |

## Fields

- `title`: the behaviour — the screen, the action, the outcome — in the
  words the product shows.
- `description`: empty.
- `preconditions`: the settings, permissions and data the behaviour needs,
  named as the user or the admin sees them.
- `steps`: one action and one `expected_result` a person can observe per
  step; `data` is the input that step types or selects.
- `tags`: the one the project uses to name its automation tool
  (`Playwright` in MS), once the spec has merged.

Every word is one a tester reads on the screen or in the admin settings.
That keeps out component names, API paths, flag keys and ticket IDs, the
words that go stale first. Take the language and the vocabulary from the
suite's other cases, and nothing else from them: older cases carry
tickets and flags.

An edit changes what was asked. Noise already in the case — a ticket in
the title, a flag in the preconditions — is named to the user, who decides
whether it goes in the same edit.

## Feature flags

Write the case for the behaviour with the flag on — the one that remains
when the flag is gone — and name no flag. Where the flag is on is the
run's concern: the run's description names the flag and its state, and
the case joins a run only where it is on. With the flag off, the
behaviour is the one the existing cases already describe.

## Parameters

A parameter is for the same steps judged once per variant: in a run, each
combination is its own row with its own result. Steps written twice with
only the `data` changed (compact, then wide) are one step and a
parameter.

- **Single**: an independent axis. Singles multiply.
- **Group**: values that travel together, one row per combination — an
  input with its expected outcome, a row of a transition table. Use it
  when only some combinations of the axes exist.
- **Shared**: an axis many cases have lives in the workspace
  (`GET /shared_parameter`) and is attached by its ID; editing it there
  changes every case. Look there before adding a local one — MS has
  表示モード (コンパクト / ワイド).

In the API's `POST /case/<CODE>`, `parameters` is a list of
`{"shared_id": "<uuid>"}`, `{"title": …, "values": […]}` for a single, and
`{"items": [{"title": …, "values": […]}, …]}` for a group, whose `values`
align by index into rows. A step cites a value as `{{<parameter title>}}`.
A value is the variant's name alone.

A case takes 1,024 combinations at most. A variant that changes the steps
themselves is another case, and an input one step uses once is `data`.

A case CI runs gets a row filled per parameter only when the spec declares
them (`qase.parameters({…})`) and the workflow's report forwards them;
otherwise CI fills one row and the others stay untested. Say so when
proposing parameters for an automated case.
