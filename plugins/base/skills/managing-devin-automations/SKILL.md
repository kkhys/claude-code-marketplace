---
name: managing-devin-automations
description: >-
  Create, inspect, edit, disable, or delete a Devin automation through the v3
  API, and write the prompt or Devin skill it runs.
disable-model-invocation: true
argument-hint: "[what to automate, or an automation URL / id]"
allowed-tools:
  - Bash(bash:*)
  - Bash(jq:*)
  - Read
  - Write
---

# Managing Devin Automations

## Request

$ARGUMENTS

## The API

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/devin-api.sh" [--all] <METHOD> <path> [body.json]
```

Paths are relative to the organization; `--all` follows the cursor of a list.
A failed call prints the problem body — on a 422 its `errors` names the field.

| Call | Use |
| - | - |
| `--all GET /automations` | List. Filters: `search`, `enabled`, `event_type`, `creator_id`, `metadata.<key>=<value>` |
| `GET /automations/<id>` | One automation; `<id>` is the last segment of its app URL |
| `GET /automations/schemas` | What this organization accepts — read it before writing a trigger |
| `GET /automations/templates` | Built-in templates: full trigger + prompt examples per use case |
| `POST /automations` | Create |
| `PATCH /automations/<id>` | Edit, enable, disable |
| `DELETE /automations/<id>` | Soft delete |
| `GET /sessions?automation_ids=<id>` | An automation's runs, with `status` and `acus_consumed`; also filters by `tags` |
| `GET /sessions/<id>/messages` | What a run did |
| `GET /sessions/<id>/insights` | Where a finished run spent its ACUs, with a revised prompt; `POST …/insights/generate` when `analysis` is empty |
| `/playbooks`, `/playbooks/<id>` | GET, POST, PUT (`title` + `body` required), DELETE |

The script reads `DEVIN_API_KEY` (a `cog_` token) and `DEVIN_ORG_ID` (`org-…`;
the slug in the app URL is not it), falling back to the Devin CLI's
`~/.config/devin/`. When it reports either missing, stop and ask the user to
set them: both are on Settings > Devin API. A 403 means the principal lacks `ViewOrgAutomations` or
`ManageOrgAutomations`.

## Steps

1. **Read the ground truth.** `GET /automations/schemas` once, and the existing
   automation closest to the request (`search=`, or `metadata.team=`). The
   schemas answer every field question below; the neighbour carries the team's
   conventions — name prefix, `run_as`, metadata, limits, concurrency,
   notifications, net policy, the sections of its prompt — which a new
   automation copies unless the user says otherwise. A `!macro` opening the
   neighbour's prompt names a shared conventions skill: read it through
   `/playbooks` before writing anything that must obey it. Done when you can
   name the event type, its condition fields, and the neighbour you copied
   from (or that none exists).
2. **Write the instructions.** Read `references/authoring.md` before writing or
   editing a prompt, a Devin skill, or a playbook.
3. **Build the body in a file** with `jq -n` or Write, the prompt passed with
   `--rawfile` so its newlines survive.
4. **Create disabled** (`"enabled": false`), then show the user the name,
   triggers, prompt, limits, and reply targets. Enable with
   `PATCH {"enabled": true}` once they agree. An edit to an enabled automation
   and a delete wait for the same agreement, shown as a before/after.
5. **Verify.** GET it back and compare with what you sent; a schedule shows
   `next_run_at`. After the first event, `last_invocation.status` and the
   run's session (`automation_ids=`) are the evidence that it works. The API has no run-now;
   the app's button has, and its event carries `"_manual": true`.

## Request body

```json
{
  "name": "Weekday dependency check",
  "enabled": false,
  "run_as": {"type": "organization"},
  "triggers": [{
    "event_type": "schedule:recurring",
    "conditions": {"any": [{"all": [
      {"field": "rrule", "operator": "recurrence",
       "value": "DTSTART;TZID=Asia/Tokyo:19700101T000000\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=9;BYMINUTE=0"}
    ]}]}
  }],
  "actions": [{
    "type": "start_session",
    "prompt": "@owner/repo @skills:dependency-check ...",
    "session": {"tags": ["dependency-check"]}
  }],
  "limits": {
    "max_acu_limit": 10,
    "invocations": {"max_per_window": 5, "window_seconds": 3600}
  }
}
```

`name`, `triggers`, `actions`, and `run_as` are required. What the field names
do not tell you:

- **Conditions** are an OR of AND-groups: `{"any": [{"all": [...]}]}`. Field
  names and operators come from the schemas' `sources.<source>.<event>.fields`.
  `null` matches every event; a Slack message trigger still needs a channel or
  another filter in each group. A bot alert is typically `channel` eq, `text`
  contains, `sender_type` eq `bot`, `is_thread_reply` eq `false`, replying
  with `attach_thread`.
- **Schedules** take one `rrule` condition. A bare `RRULE` is evaluated in
  UTC; the `DTSTART;TZID=<zone>:19700101T000000\nRRULE:…` form above, which is
  what the app writes, keeps `BYHOUR` and `BYDAY` in local time. Two cadences
  are two triggers. A one-off is
  `DTSTART:20270115T000000Z\nRRULE:FREQ=DAILY;COUNT=1`; it disables itself
  after firing.
- **The prompt is the single source of truth.** Repositories, skills, and
  playbooks are attached by tokens inside it — `@owner/repo`, `@path`,
  `@skills:name`, `@playbook:id`, `!macro`, `${SECRET_NAME}` — and
  `session.repos` / `session.playbook_id` are derived from them. An unknown id
  is a 400. The event payload is appended to the prompt automatically.
- **Actions**: one `start_session` at most. `message_session` with
  `"auto_create": true` keeps one long-lived session fed by every event.
  `monitor_session` stands alone.
- **`run_as`**: `organization` needs the organization's default service user
  and drops MCP servers connected personally; `creator` needs a personal access
  token and hides the automation from other members; `service_user` takes a
  `service_user_id`.
- **Where the answer goes** has three separate homes. `triggers[].replies`
  (`post_response`, `attach_thread`, `notify_thread`; valid verbs per event in
  `supported_replies`) answers in the triggering thread.
  `actions[].session.notifications.slack` `{mode, channel_id}` gives a session
  from a non-Slack trigger a channel. Top-level `notifications` only reports
  dispatch success or failure.
- **Limits**: set `max_acu_limit` (per session) and `invocations` explicitly
  on everything an external event can fire. `concurrency`
  `{max_concurrent_runs, max_queue_depth}` queues instead; events past the
  depth are dropped.
- **Filter before the agent runs**, cheapest first: conditions, then
  `llm_check` `{filter_prompt}`, then `script_check` `{runtime, source}` when
  the schemas report `script_check_available`. A schedule whose run usually
  finds nothing belongs in a script check: the script polls and no session
  starts on an empty day. Read `references/preflight-script.md` before writing
  one.
- **`session_settings.devin_mode`** sizes the agent to the work, from the
  schemas' `available_devin_modes`: `lite` for a sync or a tally that follows
  a fixed procedure, `ultra` for the investigation that needs it. `null` is the
  organization's default.
- **`session.tags`** group runs across automations — a team, a kind of work —
  in the session list. One automation's runs need no tag.
- **Tools**: `tools.mcp_servers` takes marketplace slugs;
  `tools.slack_channels` adds channels beyond the triggering one.
  `session_settings.net_policy` starts from the schemas' `default_net_policy`
  and can only narrow the governing security profile. An automation fed by
  text anyone can write gets a net policy listing just the hosts its
  procedure names.
- **`metadata`** is up to 16 string labels, filterable in the list — the place
  for ownership (`team`, `repo`).
- **A `webhook:incoming` trigger** (one per automation) returns its secret once,
  in the create response. Keep it out of the transcript: redirect the response
  to a `chmod 600` file, print it with
  `jq 'del(.triggers[].webhook.secret)'`, and tell the user where the file is.

## Editing

How a PATCH merges depends on the schemas' `update_semantics`: under
`merge_patch` omitted members of a sent group keep their value and `null`
clears; under `replace_groups` a sent group replaces the stored one. Lists
replace wholesale in both. So send whole groups, built from the current state:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/devin-api.sh" GET "/automations/${id}" > current.json
jq --rawfile p prompt.md \
  '{actions: (.actions | map(if .type == "start_session" then .prompt = $p else . end))}' \
  current.json > patch.json
bash "${CLAUDE_SKILL_DIR}/scripts/devin-api.sh" PATCH "/automations/${id}" patch.json
```

`llm_check` and `script_check` reject `null`; turn them off with
`{"enabled": false}` inside the group. Replacing `triggers` keeps a webhook's
secret; removing and re-adding the webhook trigger mints a new one.

## Playbooks and knowledge

Both are being folded into Devin skills, so new instructions go into a skill
(`references/authoring.md`). The schemas' `skills_serve_playbooks` tells which
side of the move the account is on: when true, the Playbooks API reads and
writes the skill each playbook became, and `!macro` and `@playbook:id` still
resolve. Devin skills themselves have no API — they are files in a repository
or entries on the Customize page.
