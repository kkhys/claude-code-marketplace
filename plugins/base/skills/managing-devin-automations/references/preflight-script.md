# Preflight script

`script_check` runs Python, Node, or Bash in a short-lived VM after a trigger
matches and before any session starts. It decides whether the actions run,
and can turn one event into several runs.

```json
"script_check": {
  "runtime": "python",
  "source": "<the script>",
  "timeout_seconds": 60,
  "secret_names": ["SENTRY_TOKEN"]
}
```

Build `source` with `jq --rawfile` from a file kept beside the body.
`secret_names` exposes organization secrets as environment variables and
needs the manage-secrets permission. On PATCH the whole group is replaced.

## Contract

Four environment variables, each holding a file path:

| Variable | Contents |
| - | - |
| `EVENT_FILE` | Read-only event: `event_type`, `source`, `payload`, `received_at` |
| `STATE_FILE` | Read-write JSON object kept between successful live runs, 64 KiB at most — a cursor, not a database |
| `LAST_RUN_FILE` | Read-only: the last 200 emitted items with `key`, `status`, `session_id` |
| `OUTPUT_FILE` | The decision, written before exiting 0 |

`OUTPUT_FILE` takes exactly one of:

- `{"run": true}` — run the actions once with the original event.
- `{"run": false, "reason": "..."}` — skip.
- `{"items": [{"id": "INC-1", "title": "..."}]}` — run the actions once per
  item; each session gets the event plus its item. `[]` skips.

Printing the decision is not enough: without valid JSON in `OUTPUT_FILE` and
exit code 0, the run fails closed and no action starts.

```python
import json, os

with open(os.environ["EVENT_FILE"]) as f:
    event = json.load(f)

urgent = "urgent" in event.get("payload", {}).get("text", "").lower()

with open(os.environ["OUTPUT_FILE"], "w") as f:
    json.dump({"run": urgent, "reason": "urgency filter"}, f)
```

## What bites

- **An item's `id` is handled once per automation.** To process the same
  entity again, add a `version` (the upstream update time). With no `id` the
  item is identified by a hash of its contents, so any change reruns it.
- **Ten new items per run** are dispatched by default (50 is the ceiling).
  The rest are dropped, not queued: emit them again next run, and advance the
  cursor in `STATE_FILE` only past what was dispatched.
- **A failed item is released** and can be emitted again; `LAST_RUN_FILE`
  tells running, succeeded, failed, and skipped apart.
- **A failed script** — nonzero exit, timeout, invalid output — stops that
  event with no retry and leaves the saved state untouched.
- **The network policy applies to the script too.** A host it polls must be
  in the automation's allowlist; attaching a secret grants no access.
- **The app's Run now skips the check** and runs the actions directly. Test
  the script in the app's script editor instead: a test run starts no session
  and saves no state, but its external requests are real.
