#!/usr/bin/env bash
set -euo pipefail

# Offline tests for place-qa-review.sh: reference rewriting, the one-pending-
# review rule, and the checks that run before the first upload. gh is a stub
# on PATH that logs every call and answers canned JSON; nothing reaches GitHub.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/place-qa-review.sh"

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

mkdir -p "${WORK_DIR}/bin" "${WORK_DIR}/qa"
export FAKE_GH_LOG="${WORK_DIR}/gh.log"
# The stub: argv of every call on one line of the log; the review body it
# receives (REST create or GraphQL update) in gh.log.review. FAKE_PENDING_BODY
# makes the lookup find a pending review with that body; FAKE_GH_FAIL_UPLOAD
# names a file whose upload fails.
cat > "${WORK_DIR}/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
{ printf 'gh'; printf ' %q' "$@"; printf '\n'; } >> "${FAKE_GH_LOG}"
case "$1 $2" in
  "pr view") echo '{"url":"https://github.com/o/r/pull/7","headRefOid":"abc123"}' ;;
  "api user") echo '{"login":"me"}' ;;
  "api repos/o/r") echo '{"id":42}' ;;
  "api --method")
    for arg in "$@"; do
      [[ "${arg}" == "${FAKE_GH_FAIL_UPLOAD:-}" ]] && { echo 'HTTP 404: Not Found' >&2; exit 1; }
    done
    n="$(grep -c 'uploads.github.com' "${FAKE_GH_LOG}")"
    echo "{\"url\":\"https://github.com/user-attachments/assets/asset-${n}\"}" ;;
  "api graphql")
    input="$(cat)"
    if [[ "${input}" == *updatePullRequestReview* ]]; then
      jq -r '.variables.body' <<< "${input}" > "${FAKE_GH_LOG}.review"
      echo '{"data":{"updatePullRequestReview":{"pullRequestReview":{"id":"R1"}}}}'
    elif [[ -n "${FAKE_PENDING_BODY:-}" ]]; then
      jq -cn --arg b "${FAKE_PENDING_BODY}" '{data:{repository:{pullRequest:{reviews:{nodes:[{id:"R1",body:$b}]}}}}}'
    else
      echo '{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[]}}}}}'
    fi ;;
  "api repos/o/r/pulls/7/reviews")
    input="$(cat)"
    jq -r '.body' <<< "${input}" > "${FAKE_GH_LOG}.review"
    jq -r '.commit_id' <<< "${input}" > "${FAKE_GH_LOG}.commit"
    echo '{"id":99}' ;;
  *) echo "unexpected gh call: $*" >&2; exit 2 ;;
esac
STUB
chmod +x "${WORK_DIR}/bin/gh"
export PATH="${WORK_DIR}/bin:${PATH}"

ok() {
  printf 'ok   %s\n' "$1"
  pass_count=$((pass_count + 1))
}

fail() {
  printf 'FAIL %s\n       %s\n' "$1" "$2" >&2
  fail_count=$((fail_count + 1))
}

# Assert that `haystack` contains `needle`.
expect_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" == *"${needle}"* ]]; then ok "${label}"; else fail "${label}" "missing: ${needle}"; fi
}

expect_lacks() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" != *"${needle}"* ]]; then ok "${label}"; else fail "${label}" "present: ${needle}"; fi
}

# Run the script from the body's directory, the way the skill does, with the
# log reset; returns the exit code and leaves the output in RUN_OUTPUT.
run() {
  local code=0
  : > "${FAKE_GH_LOG}"
  rm -f "${FAKE_GH_LOG}.review" "${FAKE_GH_LOG}.commit"
  RUN_OUTPUT="$(cd "${WORK_DIR}/qa" && bash "${SCRIPT}" "$@" 2>&1)" || code=$?
  return "${code}"
}

printf 'png' > "${WORK_DIR}/qa/1-初期表示.png"
printf 'png' > "${WORK_DIR}/qa/2-b.png"
printf 'png' > "${WORK_DIR}/qa/3-extra.png"
printf 'mp4' > "${WORK_DIR}/qa/qa.mp4"
printf 'txt' > "${WORK_DIR}/qa/notes.txt"
cat > "${WORK_DIR}/qa/qa-body.md" <<'BODY'
## Manual QA

1. 初期表示（タグあり）

![1 初期表示](./1-初期表示.png)

<a href="./2-b.png"><img width="180" alt="2 b" src="./2-b.png" /></a>

### 録画

![](./qa.mp4)
BODY

# --- A new pending review -----------------------------------------------------

if run 7 qa-body.md ./1-初期表示.png ./2-b.png ./qa.mp4 ./3-extra.png; then
  ok 'a run with every reference resolvable exits 0'
else
  fail 'a run with every reference resolvable exits 0' "${RUN_OUTPUT}"
fi
review="$(cat "${FAKE_GH_LOG}.review")"
log="$(cat "${FAKE_GH_LOG}")"
expect_contains 'an image reference is rewritten and keeps its alt' "${review}" \
  '![1 初期表示](https://github.com/user-attachments/assets/asset-1)'
expect_contains 'an <img src> is rewritten in place' "${review}" \
  'src="https://github.com/user-attachments/assets/asset-2"'
expect_contains 'an <a href> to the full-size image is rewritten in place' "${review}" \
  '<a href="https://github.com/user-attachments/assets/asset-2">'
expect_contains 'a video reference becomes the bare URL' "${review}" \
  $'### 録画\n\nhttps://github.com/user-attachments/assets/asset-3'
expect_lacks 'the video keeps no image syntax' "${review}" '![](https://github.com/user-attachments/assets/asset-3)'
expect_contains 'a file the body does not reference is appended' "${review}" \
  $'\n\n![3-extra](https://github.com/user-attachments/assets/asset-4)'
expect_lacks 'no local path survives' "${review}" './'
expect_lacks 'no attribution marker is added' "${review}" '[from Claude Code]'
expect_contains 'the file name is URL-encoded for the upload' "${log}" \
  'name=1-%E5%88%9D%E6%9C%9F%E8%A1%A8%E7%A4%BA.png\&content_type=image%2Fpng\&repository_id=42'
expect_contains 'a video uploads with its own content type' "${log}" 'name=qa.mp4\&content_type=video%2Fmp4'
expect_contains 'the upload sends raw bytes' "${log}" "-H Content-Type:\\ application/octet-stream --input ./qa.mp4"
expect_contains 'without a pending review one is created' "${log}" 'gh api repos/o/r/pulls/7/reviews --method POST --input -'
expect_contains 'the review is created on the head commit' "$(cat "${FAKE_GH_LOG}.commit")" 'abc123'
expect_contains 'the report names the PR' "${RUN_OUTPUT}" 'PENDING review created with the QA report.'

# --- An existing pending review ---------------------------------------------

export FAKE_PENDING_BODY=$'[from Claude Code] 指摘が 1 件\r\n\r\n## Manual QA\r\n\r\n| old |\r\n\r\n### 録画\r\n\r\nold-url\r\n\r\n## Other\r\n\r\nkeep'
if run 7 qa-body.md ./qa.mp4; then
  ok 'a run against an existing pending review exits 0'
else
  fail 'a run against an existing pending review exits 0' "${RUN_OUTPUT}"
fi
review="$(cat "${FAKE_GH_LOG}.review")"
log="$(cat "${FAKE_GH_LOG}")"
expect_lacks 'with a pending review none is created' "${log}" 'pulls/7/reviews --method POST'
expect_contains 'the pending review is updated instead' "${RUN_OUTPUT}" 'PENDING review updated with the QA report.'
expect_contains 'the text before the earlier section is kept' "${review}" $'[from Claude Code] 指摘が 1 件\r\n\r\n## Other\r\n\r\nkeep'
expect_lacks 'the earlier section is dropped' "${review}" '| old |'
expect_lacks 'the earlier evidence is dropped' "${review}" 'old-url'
expect_contains 'the new section follows the kept text' "${review}" $'keep\n\n## Manual QA\n'
expect_contains 'unreferenced local images stay as written' "${review}" '![1 初期表示](./1-初期表示.png)'
unset FAKE_PENDING_BODY

# --- Checks before the first upload -----------------------------------------

if run 7 qa-body.md ./1-初期表示.png ./notes.txt; then
  fail 'an unsupported type is rejected' 'exit 0'
else
  ok 'an unsupported type is rejected'
fi
expect_contains 'the rejection names the file' "${RUN_OUTPUT}" 'unsupported file type (png, jpg, gif, webp, mp4, mov, webm): ./notes.txt'
expect_lacks 'nothing uploads when a later argument is rejected' "$(cat "${FAKE_GH_LOG}")" 'uploads.github.com'

if run 7 qa-body.md ./1-初期表示.png ./missing.png; then
  fail 'a missing file is rejected' 'exit 0'
else
  ok 'a missing file is rejected'
fi
expect_contains 'the rejection names the missing file' "${RUN_OUTPUT}" 'file not found: ./missing.png'
expect_lacks 'nothing uploads when a file is missing' "$(cat "${FAKE_GH_LOG}")" 'uploads.github.com'

if run 7 "${WORK_DIR}/empty.md" ./qa.mp4; then
  fail 'an empty body is rejected' 'exit 0'
else
  ok 'an empty body is rejected'
fi

# --- A failed upload ---------------------------------------------------------

export FAKE_GH_FAIL_UPLOAD=./2-b.png
if run 7 qa-body.md ./1-初期表示.png ./2-b.png ./qa.mp4; then
  fail 'a failed upload stops the run' 'exit 0'
else
  ok 'a failed upload stops the run'
fi
expect_contains 'the failure names the file and the likely cause' "${RUN_OUTPUT}" \
  'upload failed for ./2-b.png (push access to o/r is required)'
expect_contains 'the assets uploaded before the failure are reported' "${RUN_OUTPUT}" \
  'uploaded ./1-初期表示.png -> https://github.com/user-attachments/assets/asset-1'
expect_lacks 'no review is written after a failed upload' "$(cat "${FAKE_GH_LOG}")" 'pulls/7/reviews'
if [[ ! -f "${FAKE_GH_LOG}.review" ]]; then
  ok 'no review body reaches gh after a failed upload'
else
  fail 'no review body reaches gh after a failed upload' 'review file exists'
fi
unset FAKE_GH_FAIL_UPLOAD

printf '\n%d passed, %d failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
