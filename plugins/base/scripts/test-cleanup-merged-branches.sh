#!/usr/bin/env bash
set -euo pipefail

# Offline tests for cleanup-merged-branches.sh: which local branches the Stop
# hook deletes, which it must leave alone, and how it reports.
#
# The hook runs after every turn in every repository with -D, so the keep
# cases (unmerged work, protected names, the current branch, worktree
# checkouts) guard against losing commits. The delete cases cover the two
# landing signals, ancestry and a pruned upstream; without the second,
# squash-merged branches pile up for months.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/cleanup-merged-branches.sh"

# Isolate from the developer's git config: commit signing, fetch.prune, aliases.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset CLAUDE_PROJECT_DIR

WORK="$(mktemp -d)"
readonly WORK
trap 'rm -rf "${WORK}"' EXIT

# gh is stubbed: FAKE_GH_MERGED_HEADS lists the head SHAs it reports for
# merged PRs, FAKE_GH_FAIL makes it fail like an offline or non-GitHub repo.
mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ -n "${FAKE_GH_FAIL:-}" ]] && exit 1
printf '%s\n' ${FAKE_GH_MERGED_HEADS:-}
EOF
chmod +x "${WORK}/bin/gh"
export PATH="${WORK}/bin:${PATH}"

pass_count=0
fail_count=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "${expected}" == "${actual}" ]]; then
    pass_count=$((pass_count + 1))
    echo "ok   ${name}"
  else
    fail_count=$((fail_count + 1))
    echo "FAIL ${name}"
    echo "  expected: ${expected}"
    echo "  actual:   ${actual}"
  fi
}

commit() {
  local dir="$1" name="$2"
  echo "${name}" > "${dir}/${name//\//-}.txt"
  git -C "${dir}" add -A
  git -C "${dir}" commit -q -m "${name}"
}

# A clone with one commit on main, pushed to its own bare origin.
new_repo() {
  local dir="${WORK}/$1"
  git init -q -b main "${dir}"
  commit "${dir}" init
  git init -q --bare -b main "${dir}.git"
  git -C "${dir}" remote add origin "${dir}.git"
  git -C "${dir}" push -q -u origin main
  echo "${dir}"
}

# One commit on a new branch off main, pushed with an upstream, like gh pr
# create leaves it; returns to main.
feature() {
  local dir="$1" branch="$2"
  git -C "${dir}" checkout -q -b "${branch}" main
  commit "${dir}" "${branch}"
  git -C "${dir}" push -q -u origin "${branch}"
  git -C "${dir}" checkout -q main
}

branches() {
  git -C "$1" for-each-ref refs/heads --format='%(refname:short)' | sort | xargs
}

# run_hook <dir> [VAR=value ...]
run_hook() {
  local dir="$1"
  shift
  (cd "${dir}" && env "$@" bash "${SCRIPT}" 2>> "${WORK}/stderr.log")
}

repo="$(new_repo merge-commit)"
feature "${repo}" feat/a
git -C "${repo}" merge -q --no-ff -m 'merge a' feat/a
out="$(run_hook "${repo}")"
check 'a branch landed by merge commit is deleted' \
  'main' "$(branches "${repo}")"
check 'the deletion is reported through systemMessage' \
  '{"systemMessage": "Deleted merged local branches: feat/a (merged)"}' "${out}"

repo="$(new_repo nothing)"
check 'nothing to delete prints nothing' \
  '' "$(run_hook "${repo}")"

repo="$(new_repo unmerged)"
feature "${repo}" feat/pushed
git -C "${repo}" checkout -q -b feat/local main
commit "${repo}" feat/local
git -C "${repo}" checkout -q main
run_hook "${repo}" > /dev/null
check 'unmerged branches survive, with or without an upstream' \
  'feat/local feat/pushed main' "$(branches "${repo}")"

# Squash: main gets a different commit and GitHub deletes the branch on the
# server, which leaves the local remote-tracking ref in place until a prune.
# (A local push --delete would drop that ref at once, so it is not used here.)
repo="$(new_repo squash)"
feature "${repo}" feat/squash
git -C "${repo}" merge -q --squash feat/squash > /dev/null
git -C "${repo}" commit -q -m 'squash'
git -C "${repo}.git" branch -D feat/squash > /dev/null
tip="$(git -C "${repo}" rev-parse feat/squash)"
run_hook "${repo}" "FAKE_GH_MERGED_HEADS=${tip}" > /dev/null
check 'a squash merge is invisible until the remote-tracking ref is pruned' \
  'feat/squash main' "$(branches "${repo}")"
git -C "${repo}" fetch -q --prune origin
out="$(run_hook "${repo}" "FAKE_GH_MERGED_HEADS=${tip}")"
check 'a pruned upstream whose tip headed a merged PR is deleted' \
  'main' "$(branches "${repo}")"
check 'the gone signal is named in the report' \
  '{"systemMessage": "Deleted merged local branches: feat/squash (gone)"}' "${out}"

# Same squash, but a commit was added locally after the push: deleting the
# branch would lose it, so the hook keeps it and says so.
repo="$(new_repo squash-late)"
feature "${repo}" feat/late
pushed="$(git -C "${repo}" rev-parse feat/late)"
git -C "${repo}" merge -q --squash feat/late > /dev/null
git -C "${repo}" commit -q -m 'squash'
git -C "${repo}.git" branch -D feat/late > /dev/null
git -C "${repo}" checkout -q feat/late
commit "${repo}" feat/late-extra
git -C "${repo}" checkout -q main
git -C "${repo}" fetch -q --prune origin
out="$(run_hook "${repo}" "FAKE_GH_MERGED_HEADS=${pushed}")"
check 'a gone branch with commits after the merged head survives' \
  'feat/late main' "$(branches "${repo}")"
check 'the kept branch is reported so the user can decide' \
  '{"systemMessage": "Kept, upstream gone but not the head of a merged PR: feat/late"}' "${out}"

# Without gh (offline, no GitHub remote) a gone upstream proves nothing.
repo="$(new_repo squash-offline)"
feature "${repo}" feat/offline
git -C "${repo}" merge -q --squash feat/offline > /dev/null
git -C "${repo}" commit -q -m 'squash'
git -C "${repo}.git" branch -D feat/offline > /dev/null
git -C "${repo}" fetch -q --prune origin
out="$(run_hook "${repo}" FAKE_GH_FAIL=1)"
check 'a gone branch survives silently when gh cannot confirm the merge' \
  'feat/offline main|' "$(branches "${repo}")|${out}"

# Merged on the remote by someone else; local main is still behind.
repo="$(new_repo remote-base)"
feature "${repo}" feat/remote
other="${WORK}/remote-base-other"
git clone -q "${repo}.git" "${other}"
git -C "${other}" merge -q --no-ff -m 'merge remote' origin/feat/remote
git -C "${other}" push -q origin main
git -C "${repo}" fetch -q origin
run_hook "${repo}" > /dev/null
check 'a branch merged into origin/main is deleted before local main is pulled' \
  'main' "$(branches "${repo}")"
check 'local main itself is left behind, not touched' \
  '1' "$(git -C "${repo}" rev-list --count main)"

# develop sits on the same commit as main, so only the protected list saves it.
repo="$(new_repo protected)"
git -C "${repo}" branch develop main
feature "${repo}" feat/current
git -C "${repo}" merge -q --no-ff -m 'merge current' feat/current
git -C "${repo}" checkout -q feat/current
run_hook "${repo}" > /dev/null
check 'protected and current branches survive even when merged' \
  'develop feat/current main' "$(branches "${repo}")"

repo="$(new_repo worktree)"
feature "${repo}" feat/wt
git -C "${repo}" merge -q --no-ff -m 'merge wt' feat/wt
git -C "${repo}" worktree add -q "${WORK}/worktree-checkout" feat/wt
run_hook "${repo}" > /dev/null
check 'a branch checked out in a worktree survives' \
  'feat/wt main' "$(branches "${repo}")"

repo="$(new_repo project-dir)"
feature "${repo}" feat/pd
git -C "${repo}" merge -q --no-ff -m 'merge pd' feat/pd
(cd "${WORK}" && CLAUDE_PROJECT_DIR="${repo}" bash "${SCRIPT}" > /dev/null 2>> "${WORK}/stderr.log")
check 'CLAUDE_PROJECT_DIR wins over the shell cwd' \
  'main' "$(branches "${repo}")"

rc=0
out="$(cd "${WORK}" && bash "${SCRIPT}" 2>> "${WORK}/stderr.log")" || rc=$?
check 'outside a repository it exits 0 and prints nothing' \
  '0|' "${rc}|${out}"

printf '\n%s passed, %s failed\n' "${pass_count}" "${fail_count}"
[[ "${fail_count}" -eq 0 ]]
