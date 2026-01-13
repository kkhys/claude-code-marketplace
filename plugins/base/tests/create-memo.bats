setup() {
  export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export SCRIPT_PATH="${PROJECT_ROOT}/scripts/create-memo.sh"

  export TEST_MEMO_DIR="${BATS_TEST_TMPDIR}/memo"
  mkdir -p "${TEST_MEMO_DIR}"

  export ORIGINAL_HOME="${HOME}"
  export HOME="${BATS_TEST_TMPDIR}"
  mkdir -p "${HOME}/project/private-content/memo"
}

teardown() {
  export HOME="${ORIGINAL_HOME}"
  rm -rf "${BATS_TEST_TMPDIR}/memo"
  rm -rf "${BATS_TEST_TMPDIR}/project"
}

@test "fails when no arguments provided" {
  run bash "${SCRIPT_PATH}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: Memo content is required" ]]
}

@test "creates memo directory" {
  run bash "${SCRIPT_PATH}" "Test memo content"
  [ "$status" -eq 0 ]

  local memo_count=$(find "${HOME}/project/private-content/memo" -mindepth 1 -maxdepth 1 -type d | wc -l)
  [ "$memo_count" -eq 1 ]
}

@test "creates directory with correct timestamp format" {
  run bash "${SCRIPT_PATH}" "Test memo"
  [ "$status" -eq 0 ]

  local dir_name=$(find "${HOME}/project/private-content/memo" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
  [[ "$dir_name" =~ ^[0-9]{8}_[0-9]{6}$ ]]
}

@test "creates index.md file" {
  run bash "${SCRIPT_PATH}" "Test memo"
  [ "$status" -eq 0 ]

  local memo_dir=$(find "${HOME}/project/private-content/memo" -mindepth 1 -maxdepth 1 -type d)
  [ -f "${memo_dir}/index.md" ]
}

@test "index.md contains id in frontmatter" {
  run bash "${SCRIPT_PATH}" "Test memo"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  grep -q "^id: " "${memo_file}"
}

@test "index.md contains createdAt in frontmatter" {
  run bash "${SCRIPT_PATH}" "Test memo"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  grep -q "^createdAt: " "${memo_file}"
}

@test "generates ULID with correct length" {
  run bash "${SCRIPT_PATH}" "Test memo"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  local ulid=$(grep "^id: " "${memo_file}" | cut -d' ' -f2)
  [ "${#ulid}" -eq 26 ]
}

@test "generates ULID with valid characters" {
  run bash "${SCRIPT_PATH}" "Test memo"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  local ulid=$(grep "^id: " "${memo_file}" | cut -d' ' -f2)
  # Charset matches script: 0-9, a-h, j-k, m-n, p-z (excludes i, l, o for readability)
  [[ "$ulid" =~ ^[0-9a-hj-km-np-z]{26}$ ]]
}

@test "saves memo content correctly" {
  run bash "${SCRIPT_PATH}" "This is a test memo"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  grep -q "This is a test memo" "${memo_file}"
}

@test "handles multi-line content" {
  local content="Line 1
Line 2
Line 3"

  run bash "${SCRIPT_PATH}" "$content"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  grep -q "Line 1" "${memo_file}"
  grep -q "Line 2" "${memo_file}"
  grep -q "Line 3" "${memo_file}"
}

@test "handles special characters in content" {
  run bash "${SCRIPT_PATH}" "Content with special chars: !@#$%^&*()"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")

  grep -qF "Content with special chars: !@#$%^&*()" "${memo_file}"
}

@test "handles Japanese characters" {
  run bash "${SCRIPT_PATH}" "日本語のテストメモです。"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  grep -q "日本語のテストメモです。" "${memo_file}"
}

@test "handles URLs in content" {
  run bash "${SCRIPT_PATH}" "Check this: https://example.com/path?query=value"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  grep -q "https://example.com/path?query=value" "${memo_file}"
}

@test "output is clean without emojis" {
  run bash "${SCRIPT_PATH}" "Test"
  [ "$status" -eq 0 ]

  [[ ! "$output" =~ ✅ ]]
  [[ ! "$output" =~ 📁 ]]
  [[ ! "$output" =~ 📄 ]]
  [[ ! "$output" =~ 🆔 ]]
  [[ ! "$output" =~ 📅 ]]
}

@test "createdAt has correct format" {
  run bash "${SCRIPT_PATH}" "Test"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")
  local created_at=$(grep "^createdAt: " "${memo_file}" | cut -d' ' -f2-)
  [[ "$created_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
}

@test "frontmatter is properly formatted" {
  run bash "${SCRIPT_PATH}" "Test content"
  [ "$status" -eq 0 ]

  local memo_file=$(find "${HOME}/project/private-content/memo" -name "index.md")

  local first_line=$(head -n 1 "${memo_file}")
  [ "$first_line" = "---" ]

  grep -q "^---$" "${memo_file}"

  local delimiter_count=$(grep -c "^---$" "${memo_file}")
  [ "$delimiter_count" -eq 2 ]
}
