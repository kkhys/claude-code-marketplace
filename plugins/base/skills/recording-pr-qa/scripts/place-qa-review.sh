#!/usr/bin/env bash
set -euo pipefail

# Place a QA report on a PR the user reviews: as the summary of their PENDING
# review, with the evidence files uploaded to the repository's attachment store
# and the body's references rewritten to the uploaded assets — what
# `gh pr edit --attach` does for a PR body. `gh pr review` has no --attach, so
# the two steps are done here by hand, against the same upload endpoint.
#
# Usage: place-qa-review.sh <pr> <body.md> [file...]
#   <pr>    anything `gh pr view` accepts (number, URL, branch)
#   <body>  markdown referencing the files by name, relative to its own
#           directory (run from there): `![alt](./a.png)`, `<img src="./a.png">`,
#           `<a href="./a.png">`, `![](./qa.mp4)`. An image reference keeps its alt, a video
#           reference becomes the bare URL GitHub renders as a player, and a
#           file the body does not reference is appended to it.
#
# The user holds at most one pending review per PR — GitHub refuses a second —
# so an existing one is updated, its earlier `## Manual QA` section replaced;
# otherwise one is created. Either way it stays pending: the user reads it on
# GitHub and submits it with their verdict.
#
# No attribution marker: the report is the reviewer's own vetted test record,
# submitted by them.

readonly USAGE='Usage: place-qa-review.sh <pr> <body.md> [file...]'
readonly PR="${1:?${USAGE}}"
readonly BODY_FILE="${2:?${USAGE}}"
shift 2

if [[ ! -s "${BODY_FILE}" ]]; then
  echo "Error: body file is missing or empty: ${BODY_FILE}" >&2
  exit 1
fi

# The types the upload endpoint takes, by extension; gh's --attach list.
content_type() {
  case "$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')" in
    png) echo image/png ;;
    jpg | jpeg) echo image/jpeg ;;
    gif) echo image/gif ;;
    webp) echo image/webp ;;
    mp4) echo video/mp4 ;;
    mov) echo video/quicktime ;;
    webm) echo video/webm ;;
    *) return 1 ;;
  esac
}

# Every file is checked before the first upload: an upload cannot be undone,
# so a fault in the last argument must not strand the assets before it.
for file in "$@"; do
  if [[ ! -f "${file}" ]]; then
    echo "Error: file not found: ${file}" >&2
    exit 1
  fi
  if ! content_type "${file}" > /dev/null; then
    echo "Error: unsupported file type (png, jpg, gif, webp, mp4, mov, webm): ${file}" >&2
    exit 1
  fi
done

# GH_NO_UPDATE_NOTIFIER: stderr is merged into the captured value to surface
# gh's error on failure; an upgrade notice would corrupt it on success.
if ! pr_json="$(GH_NO_UPDATE_NOTIFIER=1 gh pr view "${PR}" --json url,headRefOid 2>&1)"; then
  echo "Error: pull request not found (${pr_json})" >&2
  exit 1
fi
PR_URL="$(jq -r '.url' <<< "${pr_json}")"
readonly PR_URL
HEAD_OID="$(jq -r '.headRefOid' <<< "${pr_json}")"
readonly HEAD_OID

if [[ ! "${PR_URL}" =~ ^https?://([^/]+)/([^/]+)/([^/]+)/pull/([0-9]+)$ ]]; then
  echo "Error: cannot read owner, repository and number from ${PR_URL}" >&2
  exit 1
fi
readonly HOST="${BASH_REMATCH[1]}"
readonly OWNER="${BASH_REMATCH[2]}"
readonly REPO="${BASH_REMATCH[3]}"
readonly PR_NUMBER="${BASH_REMATCH[4]}"

# The endpoint wants the repository's numeric id, and it answers 404 to a
# token without push access — the error names that case.
REPO_ID="$(gh api "repos/${OWNER}/${REPO}" | jq -r '.id')"
readonly REPO_ID
VIEWER="$(gh api user | jq -r '.login')"
readonly VIEWER
readonly UPLOAD_URL="https://uploads.${HOST}/user-attachments/assets"

upload() {
  local name type response
  name="$(jq -rn --arg s "$(basename "$1")" '$s | @uri')"
  type="$(jq -rn --arg s "$2" '$s | @uri')"
  if ! response="$(gh api --method POST \
    "${UPLOAD_URL}?name=${name}&content_type=${type}&repository_id=${REPO_ID}" \
    -H 'Content-Type: application/octet-stream' --input "$1")"; then
    echo "Error: upload failed for $1 (push access to ${OWNER}/${REPO} is required)" >&2
    return 1
  fi
  jq -er '.url | select(. != "")' <<< "${response}" || {
    echo "Error: the server returned no asset URL for $1" >&2
    return 1
  }
}

body="$(cat "${BODY_FILE}")"
uploaded=0
for file in "$@"; do
  name="$(basename "${file}")"
  type="$(content_type "${file}")"
  # Uploaded URLs are printed as they come: when a later upload fails, the
  # earlier assets exist and these lines are the only record of them.
  url="$(upload "${file}" "${type}")"
  echo "uploaded ${file} -> ${url}" >&2
  uploaded=$((uploaded + 1))
  before="${body}"
  body="${body//"(./${name})"/"(${url})"}"
  body="${body//"(${name})"/"(${url})"}"
  body="${body//"\"./${name}\""/"\"${url}\""}"
  body="${body//"\"${name}\""/"\"${url}\""}"
  if [[ "${type}" == video/* ]]; then
    # A video renders as a player only as a bare URL, not inside image syntax.
    body="$(sed -E "s~!\[[^]]*\]\(${url}\)~${url}~g" <<< "${body}")"
  fi
  if [[ "${body}" == "${before}" ]]; then
    if [[ "${type}" == video/* ]]; then
      body+=$'\n\n'"${url}"
    else
      body+=$'\n\n'"![${name%.*}](${url})"
    fi
  fi
done

# The user's own pending review, if one exists: posting-pr-review's, or an
# earlier run's.
# shellcheck disable=SC2016  # $owner and friends are GraphQL variables, not shell ones
readonly LOOKUP='query($owner: String!, $repo: String!, $number: Int!, $author: String!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviews(states: PENDING, author: $author, first: 1) { nodes { id body } }
    }
  }
}'
pending="$(jq -cn --arg query "${LOOKUP}" --arg owner "${OWNER}" --arg repo "${REPO}" \
  --argjson number "${PR_NUMBER}" --arg author "${VIEWER}" \
  '{query: $query, variables: {owner: $owner, repo: $repo, number: $number, author: $author}}' \
  | gh api graphql --input -)"
REVIEW_ID="$(jq -r '.data.repository.pullRequest.reviews.nodes[0].id // empty' <<< "${pending}")"
readonly REVIEW_ID

if [[ -n "${REVIEW_ID}" ]]; then
  # Drop the earlier section — from its heading to the next heading or rule —
  # and append the new one after whatever else the review says.
  existing="$(jq -r '.data.repository.pullRequest.reviews.nodes[0].body' <<< "${pending}" \
    | awk '/^## Manual QA[[:space:]]*$/ { skip = 1; next }
           skip && (/^## / || /^---/) { skip = 0 }
           !skip')"
  existing="${existing%"${existing##*[![:space:]]}"}"
  if [[ -n "${existing}" ]]; then
    body="${existing}"$'\n\n'"${body}"
  fi
  # shellcheck disable=SC2016  # $id and $body are GraphQL variables, not shell ones
  readonly MUTATION='mutation($id: ID!, $body: String!) {
    updatePullRequestReview(input: {pullRequestReviewId: $id, body: $body}) { pullRequestReview { id } }
  }'
  jq -cn --arg query "${MUTATION}" --arg id "${REVIEW_ID}" --arg body "${body}" \
    '{query: $query, variables: {id: $id, body: $body}}' \
    | gh api graphql --input - > /dev/null
  verb="updated"
else
  # event omitted = PENDING
  jq -cn --arg commit_id "${HEAD_OID}" --arg body "${body}" '{commit_id: $commit_id, body: $body}' \
    | gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" --method POST --input - > /dev/null
  verb="created"
fi

echo "PENDING review ${verb} with the QA report."
echo "  Files: ${uploaded}"
echo "  PR: ${PR_URL}"
