#!/usr/bin/env bash
set -euo pipefail

# Offline tests for read-unresolved-pr-comments.sh, using a gh stub on PATH.
#
# Pins the two regressions this script had: comments attached to a PENDING
# review leaked into the output (exposing someone's unsent draft), and Bot /
# Team reviewers turned into null because only the User fragment was queried.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/read-unresolved-pr-comments.sh"

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# gh stub: repo/PR context plus a canned GraphQL response. The real gh would
# need a network and a live PR; the script's own logic is what needs pinning.
mkdir -p "${WORK_DIR}/bin"
cat > "${WORK_DIR}/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") printf 'kkhys/demo\n' ;;
  "pr view") printf '{"number":42,"url":"https://github.com/kkhys/demo/pull/42","headRefOid":"abc1234"}\n' ;;
  "api graphql") cat "${GH_FIXTURE:?}" ;;
  *) printf 'gh stub: unexpected call: %s\n' "$*" >&2; exit 64 ;;
esac
EOF
chmod +x "${WORK_DIR}/bin/gh"

cat > "${WORK_DIR}/fixture.json" <<'EOF'
{
  "data": {
    "repository": {
      "pullRequest": {
        "number": 42,
        "title": "[main] feat: add thing",
        "url": "https://github.com/kkhys/demo/pull/42",
        "state": "OPEN",
        "author": { "login": "kkhys" },
        "reviewRequests": {
          "nodes": [
            { "requestedReviewer": { "__typename": "Bot", "login": "copilot-pull-request-reviewer" } },
            { "requestedReviewer": { "__typename": "Team", "slug": "platform" } },
            { "requestedReviewer": { "__typename": "User", "login": "alice" } }
          ]
        },
        "reviewThreads": {
          "nodes": [
            {
              "id": "T_SUBMITTED",
              "isResolved": false,
              "isOutdated": false,
              "path": "a.sh",
              "line": 1,
              "startLine": null,
              "comments": { "nodes": [
                { "author": { "login": "alice" }, "authorAssociation": "MEMBER",
                  "body": "quote this", "url": "https://example.test/c1",
                  "createdAt": "2026-08-08T00:00:00Z",
                  "pullRequestReview": { "state": "SUBMITTED" } }
              ] }
            },
            {
              "id": "T_PENDING_ONLY",
              "isResolved": false,
              "isOutdated": false,
              "path": "b.sh",
              "line": 2,
              "startLine": null,
              "comments": { "nodes": [
                { "author": { "login": "kkhys" }, "authorAssociation": "OWNER",
                  "body": "unsent draft", "url": "https://example.test/c2",
                  "createdAt": "2026-08-08T00:00:00Z",
                  "pullRequestReview": { "state": "PENDING" } }
              ] }
            },
            {
              "id": "T_RESOLVED",
              "isResolved": true,
              "isOutdated": false,
              "path": "c.sh",
              "line": 3,
              "startLine": null,
              "comments": { "nodes": [
                { "author": null, "authorAssociation": "NONE",
                  "body": "done", "url": "https://example.test/c3",
                  "createdAt": "2026-08-08T00:00:00Z",
                  "pullRequestReview": { "state": "SUBMITTED" } }
              ] }
            }
          ]
        }
      }
    }
  }
}
EOF

OUTPUT="$(PATH="${WORK_DIR}/bin:${PATH}" GH_FIXTURE="${WORK_DIR}/fixture.json" bash "${SCRIPT}")"
readonly OUTPUT

check() {
  local label="$1" expected="$2" filter="$3" actual
  actual="$(jq -c "${filter}" <<< "${OUTPUT}")"
  if [[ "${expected}" == "${actual}" ]]; then
    printf 'ok   %s\n' "${label}"
    pass_count=$((pass_count + 1))
  else
    printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' \
      "${label}" "${expected}" "${actual}" >&2
    fail_count=$((fail_count + 1))
  fi
}

check 'PR context comes from the stubbed gh' \
  '[42,"OPEN","kkhys"]' '[.pr_number, .state, .author]'

check 'Bot and Team reviewers resolve to a name instead of null' \
  '["copilot-pull-request-reviewer","platform","alice"]' '.requested_reviewers'

check 'a thread whose only comment is an unsent PENDING draft is not surfaced' \
  '["T_SUBMITTED"]' '[.unresolved_threads[].thread_id]'

check 'resolved threads are excluded' \
  'false' '[.unresolved_threads[].thread_id] | index("T_RESOLVED") != null'

check 'published comments keep their fields' \
  '["alice","quote this"]' '[.unresolved_threads[0].comments[0] | .author, .body]'

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
