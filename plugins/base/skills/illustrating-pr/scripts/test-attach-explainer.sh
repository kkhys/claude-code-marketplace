#!/usr/bin/env bash
set -euo pipefail

# Offline tests for attach-explainer.sh and theme-images.py.
#
# gh is replaced by a stub on PATH that records its arguments and working
# directory and mimics the calls the script depends on: `pr comment` and
# `pr edit` rewrite every attached ./file reference to an asset URL the way
# gh does and store the text, `pr view` serves the stored description, and
# `api` serves a stored comment back or records the PATCH. The tests cover
# the validation that runs before any upload, the exact commands the real gh
# receives, the fenced section in a description, and the <picture> rewrite,
# without touching GitHub.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/attach-explainer.sh"

pass_count=0
fail_count=0

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

readonly STUB_DIR="${WORK_DIR}/bin"
readonly STATE="${WORK_DIR}/state"
mkdir -p "${STUB_DIR}" "${STATE}"
cat > "${STUB_DIR}/gh" <<EOF
#!/usr/bin/env bash
# GH_STUB_EXIT makes the comment call fail; GH_STUB_URL replaces the URL it prints.
set -euo pipefail
STATE="${STATE}"
PR_URL="https://github.com/o/r/pull/42"

# Rewrite every attached ./name reference in \$1 the way gh does, in place.
rewrite_attachments() {
  local body="\$1"; shift
  local path name stem escaped
  for path in "\$@"; do
    name="\${path#./}"
    stem="\${name%.*}"
    escaped="\${name//./\\\\.}"
    sed -i.bak "s|(\\./\${escaped})|(https://github.com/user-attachments/assets/\${stem}-0000)|g" "\${body}"
  done
  rm -f "\${body}.bak"
}

body=""
attached=()
for ((i = 1; i <= \$#; i++)); do
  case "\${!i}" in
    --body-file) j=\$((i + 1)); body="\${!j}" ;;
    --attach) j=\$((i + 1)); attached+=("\${!j}") ;;
  esac
done

case "\$1 \$2" in
  "repo view")
    echo "o/r"
    ;;
  "pr view")
    [[ -f "\${STATE}/pr-body.md" ]] || : > "\${STATE}/pr-body.md"
    if [[ "\$*" == *"--jq .body"* ]]; then
      cat "\${STATE}/pr-body.md"
    else
      jq -n --arg url "\${PR_URL}" --rawfile body "\${STATE}/pr-body.md" '{url: \$url, body: \$body}'
    fi
    ;;
  "pr edit")
    echo "cwd=\$PWD" >> "\${STATE}/edit.log"
    echo "args=\$*" >> "\${STATE}/edit.log"
    cp "\${body}" "\${STATE}/pr-body.md"
    rewrite_attachments "\${STATE}/pr-body.md" "\${attached[@]:-}"
    echo "\${PR_URL}"
    ;;
  "pr comment")
    { echo "cwd=\$PWD"; echo "args=\$*"; } > "\${STATE}/comment.log"
    cp "\${body}" "\${STATE}/uploaded.md"
    cp "\${body}" "\${STATE}/posted.md"
    rewrite_attachments "\${STATE}/posted.md" "\${attached[@]:-}"
    if [[ -n "\${GH_STUB_EXIT:-}" ]]; then exit "\${GH_STUB_EXIT}"; fi
    echo "\${GH_STUB_URL:-\${PR_URL}#issuecomment-1}"
    ;;
  "api -X")
    echo "patch=\$4" > "\${STATE}/patch.log"
    for ((i = 1; i <= \$#; i++)); do
      if [[ "\${!i}" == "--input" ]]; then j=\$((i + 1)); jq -r .body "\${!j}" > "\${STATE}/patched.md"; fi
    done
    ;;
  api*)
    echo "get=\$2" > "\${STATE}/get.log"
    cat "\${STATE}/posted.md"
    ;;
  *)
    echo "unexpected gh call: \$*" >&2
    exit 99
    ;;
esac
EOF
chmod +x "${STUB_DIR}/gh"
export PATH="${STUB_DIR}:${PATH}"

readonly PANELS="${WORK_DIR}/panels"
mkdir -p "${PANELS}"
printf 'png' > "${PANELS}/01-a.png"
printf 'png' > "${PANELS}/02-b.png"
printf 'png' > "${PANELS}/01-a.dark.png"
printf 'png' > "${PANELS}/02-b.dark.png"
printf 'bmp' > "${PANELS}/03-c.bmp"
cat > "${PANELS}/body.md" <<'EOF'
Pictures for `abc1234`.

### 1. A
![A "quoted" & co](./01-a.png)

### 2. B
![B](./02-b.png)
EOF

ok() {
  printf 'ok   %s\n' "$1"
  pass_count=$((pass_count + 1))
}

fail() {
  printf 'FAIL %s\n       %s\n' "$1" "$2" >&2
  fail_count=$((fail_count + 1))
}

reset_state() {
  rm -f "${STATE}"/*
}

# Assert the script's exit code and that its output mentions `expect_output`.
# The stub state is kept between calls so a rerun can be tested; call
# reset_state first when a clean slate matters.
expect_result() {
  local label="$1" expect_code="$2" expect_output="$3"
  shift 3
  local output code=0
  output="$(bash "${SCRIPT}" "$@" 2>&1)" || code=$?
  if [[ "${code}" -eq "${expect_code}" && "${output}" == *"${expect_output}"* ]]; then
    ok "${label}"
  else
    fail "${label}" "expected: exit ${expect_code} containing $(printf '%q' "${expect_output}"); actual: exit ${code}: ${output}"
  fi
}

assert_file_contains() {
  local label="$1" file="$2" needle="$3"
  if [[ -f "${file}" ]] && grep -qF -- "${needle}" "${file}"; then
    ok "${label}"
  else
    fail "${label}" "missing $(printf '%q' "${needle}") in ${file}: $(cat "${file}" 2>/dev/null)"
  fi
}

assert_file_lacks() {
  local label="$1" file="$2" needle="$3"
  if [[ -f "${file}" ]] && ! grep -qF -- "${needle}" "${file}"; then
    ok "${label}"
  else
    fail "${label}" "found $(printf '%q' "${needle}") in ${file}: $(cat "${file}" 2>/dev/null)"
  fi
}

assert_count() {
  local label="$1" file="$2" needle="$3" expected="$4" actual
  actual="$(grep -cF -- "${needle}" "${file}" 2>/dev/null || true)"
  if [[ "${actual}" == "${expected}" ]]; then
    ok "${label}"
  else
    fail "${label}" "expected ${expected} of $(printf '%q' "${needle}"), got ${actual}: $(cat "${file}" 2>/dev/null)"
  fi
}

# --- validation, nothing reaches gh ---------------------------------------

reset_state
expect_result 'too few arguments print usage' 1 'Usage:' 42 "${PANELS}/body.md"

expect_result 'a missing body file is rejected' 1 'body file missing or empty' \
  42 "${PANELS}/nope.md" "${PANELS}/01-a.png"

expect_result 'a missing image is rejected' 1 'image not found' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/99-z.png"

expect_result 'an unsupported image type is rejected' 1 'unsupported image type' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/03-c.bmp"

printf 'png' > "${PANELS}/03-c.png"
expect_result 'an image the body never references is rejected' 1 'not referenced in the body' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png" "${PANELS}/03-c.png"

cat "${PANELS}/body.md" > "${PANELS}/twice.md"
echo '![A again](./01-a.png)' >> "${PANELS}/twice.md"
expect_result 'an image referenced twice is rejected' 1 'referenced more than once' \
  42 "${PANELS}/twice.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"

# A sparse file one byte over the limit; nothing is actually written.
dd if=/dev/zero of="${PANELS}/big.png" bs=1 count=1 seek=$((10 * 1024 * 1024)) 2>/dev/null
expect_result 'an image over 10 MiB is rejected' 1 'at most' \
  42 "${PANELS}/body.md" "${PANELS}/big.png"

mkdir -p "${WORK_DIR}/elsewhere"
printf 'png' > "${WORK_DIR}/elsewhere/02-b.png"
expect_result 'images in two directories are rejected' 1 'must share one directory' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${WORK_DIR}/elsewhere/02-b.png"

expect_result 'a dark twin without its light file is rejected' 1 'has no light twin' \
  42 "${PANELS}/body.md" "${PANELS}/02-b.png" "${PANELS}/01-a.dark.png"

cat "${PANELS}/body.md" > "${PANELS}/darkref.md"
echo '![A dark](./01-a.dark.png)' >> "${PANELS}/darkref.md"
expect_result 'a dark twin referenced by hand is rejected' 1 'paired with 01-a.png automatically' \
  42 "${PANELS}/darkref.md" "${PANELS}/01-a.png" "${PANELS}/01-a.dark.png"

{ echo '<!-- illustrating-pr:start -->'; cat "${PANELS}/body.md"; } > "${PANELS}/marked-section.md"
expect_result 'a body carrying the section markers is rejected' 1 'must not contain the section markers' \
  42 "${PANELS}/marked-section.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"

if [[ ! -e "${STATE}/comment.log" && ! -e "${STATE}/edit.log" ]]; then
  ok 'validation failures never invoke gh'
else
  fail 'validation failures never invoke gh' "gh was invoked: $(cat "${STATE}"/comment.log "${STATE}"/edit.log 2>/dev/null)"
fi

# --- description (default): fenced section after the author's bullets -----

reset_state
printf -- '- Add x\n- Fix y\n\n![shot](https://github.com/user-attachments/assets/existing-0000)\n' > "${STATE}/pr-body.md"
expect_result 'a valid payload updates the description' 0 'https://github.com/o/r/pull/42' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"

if grep -qE -- '^args=pr edit 42 -R o/r --body-file .*/upload\.md --attach \./01-a\.png --attach \./02-b\.png$' "${STATE}/edit.log"; then
  ok 'gh pr edit receives the PR pinned to the current repo, the body file, and every image as ./name'
else
  fail 'gh pr edit receives the PR pinned to the current repo, the body file, and every image as ./name' "$(grep '^args=' "${STATE}/edit.log")"
fi

if grep -qx -- "cwd=$(cd "${PANELS}" && pwd)" "${STATE}/edit.log"; then
  ok 'gh runs from the image directory so ./name resolves to the attachment'
else
  fail 'gh runs from the image directory so ./name resolves to the attachment' "$(grep '^cwd=' "${STATE}/edit.log")"
fi

if [[ "$(head -n 2 "${STATE}/pr-body.md")" == $'- Add x\n- Fix y' ]]; then
  ok 'the author bullets stay first and untouched'
else
  fail 'the author bullets stay first and untouched' "$(head -n 3 "${STATE}/pr-body.md")"
fi
assert_file_contains 'an image the author placed earlier is kept' "${STATE}/pr-body.md" 'assets/existing-0000'
assert_file_contains 'the section opens with its marker' "${STATE}/pr-body.md" '<!-- illustrating-pr:start -->'
if grep -A1 -F '<!-- illustrating-pr:start -->' "${STATE}/pr-body.md" | grep -qx '## In pictures'; then
  ok 'the section carries an English heading right after the marker'
else
  fail 'the section carries an English heading right after the marker' "$(grep -A2 -F 'illustrating-pr:start' "${STATE}/pr-body.md")"
fi
assert_file_contains 'the section closes with its marker' "${STATE}/pr-body.md" '<!-- illustrating-pr:end -->'
assert_file_contains 'the section text starts with the attribution marker' "${STATE}/pr-body.md" "[from Claude Code] Pictures for \`abc1234\`."
assert_file_contains 'the image references are rewritten to assets' "${STATE}/pr-body.md" '![A "quoted" & co](https://github.com/user-attachments/assets/01-a-0000)'
if [[ ! -e "${STATE}/comment.log" ]]; then
  ok 'the description mode posts no comment'
else
  fail 'the description mode posts no comment' "$(cat "${STATE}/comment.log")"
fi

# Rerun: the section is replaced, not stacked.
expect_result 'a rerun succeeds' 0 'https://github.com/o/r/pull/42' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"
assert_count 'a rerun leaves exactly one section start' "${STATE}/pr-body.md" '<!-- illustrating-pr:start -->' 1
assert_count 'a rerun leaves exactly one section end' "${STATE}/pr-body.md" '<!-- illustrating-pr:end -->' 1
assert_count 'a rerun keeps the author image once' "${STATE}/pr-body.md" 'assets/existing-0000' 1
if [[ "$(head -n 2 "${STATE}/pr-body.md")" == $'- Add x\n- Fix y' ]]; then
  ok 'a rerun keeps the bullets first'
else
  fail 'a rerun keeps the bullets first' "$(head -n 3 "${STATE}/pr-body.md")"
fi

# Dark twins in a description: themed inside the section, the author's image untouched.
reset_state
printf -- '- Add x\n\n![shot](https://github.com/user-attachments/assets/existing-0000)\n' > "${STATE}/pr-body.md"
expect_result 'dark twins update the description and theme it' 0 'themed   2 panels' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png" "${PANELS}/01-a.dark.png" "${PANELS}/02-b.dark.png"
if [[ "$(grep -c '^args=' "${STATE}/edit.log")" == "2" && "$(grep '^args=' "${STATE}/edit.log" | tail -n 1)" != *"--attach"* ]]; then
  ok 'the second edit rewrites the body and carries no attachments'
else
  fail 'the second edit rewrites the body and carries no attachments' "$(grep '^args=' "${STATE}/edit.log")"
fi
assert_file_contains 'the dark asset becomes the dark source' "${STATE}/pr-body.md" \
  '<source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/01-a.dark-0000">'
assert_file_contains 'the light asset stays the img fallback' "${STATE}/pr-body.md" \
  '<img alt="A &quot;quoted&quot; &amp; co" src="https://github.com/user-attachments/assets/01-a-0000">'
assert_file_lacks 'the appended dark references are removed' "${STATE}/pr-body.md" '01-a.dark.png'
assert_file_contains 'the author image outside the section is not touched' "${STATE}/pr-body.md" '![shot](https://github.com/user-attachments/assets/existing-0000)'
assert_file_contains 'the markers survive the rewrite' "${STATE}/pr-body.md" '<!-- illustrating-pr:end -->'

# An empty description gets just the section.
reset_state
: > "${STATE}/pr-body.md"
expect_result 'an empty description works' 0 'https://github.com/o/r/pull/42' \
  42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"
if [[ "$(head -n 1 "${STATE}/pr-body.md")" == '<!-- illustrating-pr:start -->' ]]; then
  ok 'an empty description starts with the section'
else
  fail 'an empty description starts with the section' "$(head -n 2 "${STATE}/pr-body.md")"
fi

# --- comment mode ----------------------------------------------------------

reset_state
expect_result '--comment posts one comment' 0 'issuecomment-1' \
  --comment 42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"
if grep -qE -- '^args=pr comment 42 -R o/r --body-file .*/section\.md --attach \./01-a\.png --attach \./02-b\.png$' "${STATE}/comment.log"; then
  ok 'gh pr comment receives the PR, the body file, and every image as ./name'
else
  fail 'gh pr comment receives the PR, the body file, and every image as ./name' "$(grep '^args=' "${STATE}/comment.log")"
fi
assert_file_contains 'the comment starts with the attribution marker' "${STATE}/uploaded.md" "[from Claude Code] Pictures for \`abc1234\`."
assert_file_lacks 'the comment carries no section markers' "${STATE}/uploaded.md" 'illustrating-pr:start'
assert_file_lacks 'the comment carries no section heading' "${STATE}/uploaded.md" '## In pictures'
if [[ ! -e "${STATE}/edit.log" ]]; then
  ok 'the comment mode leaves the description alone'
else
  fail 'the comment mode leaves the description alone' "$(cat "${STATE}/edit.log")"
fi
if [[ ! -e "${STATE}/get.log" && ! -e "${STATE}/patch.log" ]]; then
  ok 'without dark twins the comment is left as posted'
else
  fail 'without dark twins the comment is left as posted' "api calls: $(cat "${STATE}"/get.log "${STATE}"/patch.log 2>/dev/null)"
fi

sed '1s/^/[from Claude Code] /' "${PANELS}/body.md" > "${PANELS}/marked.md"
expect_result 'a pre-marked body posts unchanged' 0 'issuecomment-1' \
  --comment 42 "${PANELS}/marked.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"
assert_count 'the attribution marker is idempotent' "${STATE}/uploaded.md" '[from Claude Code]' 1

expect_result 'a PR URL is passed to gh as given' 0 'issuecomment-1' \
  --comment https://github.com/o/r/pull/42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"
if grep -q '^args=pr comment https://github.com/o/r/pull/42 --body-file ' "${STATE}/comment.log"; then
  ok 'the PR URL reaches gh without a repo flag'
else
  fail 'the PR URL reaches gh without a repo flag' "$(grep '^args=' "${STATE}/comment.log")"
fi

GH_STUB_EXIT=3 expect_result 'a gh failure propagates its exit code' 3 '' \
  --comment 42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png"

reset_state
expect_result 'dark twins post a comment and theme it' 0 'themed   2 panels' \
  --comment 42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/02-b.png" "${PANELS}/01-a.dark.png" "${PANELS}/02-b.dark.png"
assert_file_contains 'dark twins are uploaded as references appended to the body' \
  "${STATE}/uploaded.md" '![01-a.dark.png](./01-a.dark.png)'
assert_file_contains 'the stored comment is fetched by its id' "${STATE}/get.log" 'get=repos/o/r/issues/comments/1'
assert_file_contains 'the same comment is patched' "${STATE}/patch.log" 'patch=repos/o/r/issues/comments/1'
assert_file_contains 'the comment gets the dark source' "${STATE}/patched.md" \
  'srcset="https://github.com/user-attachments/assets/02-b.dark-0000"'
assert_file_lacks 'no markdown image embed survives for a themed panel' "${STATE}/patched.md" '![B]('
assert_file_contains 'headings survive the rewrite' "${STATE}/patched.md" '### 2. B'

GH_STUB_URL='not a url' expect_result 'an unparsable comment URL fails after posting and says so' 1 \
  'comment posted, but its URL could not be parsed' \
  --comment 42 "${PANELS}/body.md" "${PANELS}/01-a.png" "${PANELS}/01-a.dark.png"

printf '\n%d passed, %d failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
