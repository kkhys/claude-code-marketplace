#!/usr/bin/env bash
#
# Generate portable Agent Skills from this marketplace's Claude Code skills.
#
# Source of truth: plugins/<plugin>/skills/<skill>/SKILL.md in this repository.
# Output:          <out>/skills/<skill>/ — the layout that gh skill and
#                  npx skills discover (skills/*/SKILL.md).
#
# The transform is fully deterministic: no model is involved, so the same
# input always produces the same output and --check can gate CI.
#
# Usage:
#   sync-skills.sh --out <skills-repo-dir>
#   sync-skills.sh --out <skills-repo-dir> --check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SKILL_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"
readonly REPO_ROOT

readonly MANIFEST="${SKILL_DIR}/portable-skills.txt"
readonly MARKER=".generated-by-sync-skills"
readonly DROP_KEYS="context,agent,hooks,model,effort,disable-model-invocation,user-invocable"
readonly GENERATED_HEADER="<!-- Generated from kkhys/claude-code-marketplace. Do not edit; edit the source skill and re-run sync-skills.sh. -->"
readonly SKILL_DIR_NOTE="> \`<SKILL_DIR>\` refers to the directory that contains this SKILL.md file."
readonly ASSET_DIRS=("scripts" "references" "assets")

OUT_DIR=""
CHECK_MODE=0
TMP_ROOT=""

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: sync-skills.sh --out <skills-repo-dir> [--check]

  --out <dir>   Target skills repository (writes <dir>/skills/)
  --check       Do not write; fail if <dir>/skills is out of date
  -h, --help    Show this help
EOF
}

cleanup() {
  if [[ -n "${TMP_ROOT}" && -d "${TMP_ROOT}" ]]; then
    rm -rf "${TMP_ROOT}"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out)
        [[ $# -ge 2 ]] || die "--out requires a directory"
        OUT_DIR="$2"
        shift 2
        ;;
      --check)
        CHECK_MODE=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "unknown argument: $1"
        ;;
    esac
  done

  [[ -n "${OUT_DIR}" ]] || {
    usage >&2
    die "--out is required"
  }
  [[ -d "${OUT_DIR}" ]] || die "output directory does not exist: ${OUT_DIR}"
  OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
}

# Split SKILL.md into frontmatter and body. Exits non-zero on malformed input.
split_skill() {
  local src="$1" fm="$2" body="$3"

  awk -v fm="${fm}" -v body="${body}" '
    NR == 1 {
      if ($0 != "---") { exit 3 }
      next
    }
    !seen && $0 == "---" { seen = 1; next }
    !seen { print > fm; next }
    { print > body }
    END { if (!seen) { exit 3 } }
  ' "${src}"
}

# Drop Claude Code specific frontmatter keys along with their indented values.
transform_frontmatter() {
  awk -v drop="${DROP_KEYS}" '
    BEGIN {
      n = split(drop, keys, ",")
      for (i = 1; i <= n; i++) { dropkey[keys[i]] = 1 }
    }
    {
      if (match($0, /^[A-Za-z0-9_-]+:/)) {
        skip = (substr($0, 1, RLENGTH - 1) in dropkey)
      }
      if (!skip) { print }
    }
  ' "$1"
}

# Keep the portable variant of each annotated block, drop the Claude variant.
transform_body() {
  awk '
    /^[[:space:]]*<!--[[:space:]]*claude:start[[:space:]]*-->[[:space:]]*$/ { inclaude = 1; next }
    /^[[:space:]]*<!--[[:space:]]*claude:end[[:space:]]*-->[[:space:]]*$/   { inclaude = 0; next }
    /^[[:space:]]*<!--[[:space:]]*portable:start[[:space:]]*-->[[:space:]]*$/ { next }
    /^[[:space:]]*<!--[[:space:]]*portable:end[[:space:]]*-->[[:space:]]*$/   { next }
    inclaude { next }
    { print }
  ' "$1"
}

# Reject constructs that only work in Claude Code. Reaching this point means
# the author forgot to wrap them in a claude:/portable: block pair.
validate_output() {
  local file="$1" id="$2" errors=0

  # Anchored so that inline literals such as `!` in prose do not false-positive.
  if grep -qE '(^|[^`])!`[^`]' "${file}"; then
    warn "${id}: dynamic context injection (!\`cmd\`) left in portable output"
    errors=1
  fi
  if grep -qF 'CLAUDE_PLUGIN_ROOT' "${file}"; then
    warn "${id}: \${CLAUDE_PLUGIN_ROOT} has no portable equivalent"
    errors=1
  fi
  if grep -qF '$ARGUMENTS' "${file}"; then
    warn "${id}: \$ARGUMENTS is a Claude Code substitution"
    errors=1
  fi
  if ! grep -qE '^name:[[:space:]]*[a-z0-9-]+[[:space:]]*$' "${file}"; then
    warn "${id}: frontmatter is missing a spec-compliant lowercase name"
    errors=1
  fi
  if ! grep -qE '^description:' "${file}"; then
    warn "${id}: frontmatter is missing description"
    errors=1
  fi

  return "${errors}"
}

build_skill() {
  local plugin="$1" skill="$2" dest_root="$3"
  local src_dir="${REPO_ROOT}/plugins/${plugin}/skills/${skill}"
  local src="${src_dir}/SKILL.md"
  local dest_dir="${dest_root}/${skill}"
  local id="${plugin}/${skill}"

  [[ -f "${src}" ]] || die "${id}: SKILL.md not found"

  local work fm body fm_t body_t
  work="$(mktemp -d)"
  fm="${work}/frontmatter"
  body="${work}/body"
  fm_t="${work}/frontmatter.out"
  body_t="${work}/body.out"
  : >"${fm}"
  : >"${body}"

  split_skill "${src}" "${fm}" "${body}" || die "${id}: malformed frontmatter"

  transform_frontmatter "${fm}" >"${fm_t}"
  transform_body "${body}" |
    sed -e 's/\${CLAUDE_SKILL_DIR}/<SKILL_DIR>/g' -e 's/\$CLAUDE_SKILL_DIR/<SKILL_DIR>/g' \
      >"${body_t}"

  mkdir -p "${dest_dir}"
  {
    printf -- '---\n'
    cat "${fm_t}"
    printf -- '---\n\n'
    printf '%s\n' "${GENERATED_HEADER}"
    if grep -qF '<SKILL_DIR>' "${body_t}"; then
      printf '%s\n' "${SKILL_DIR_NOTE}"
    fi
    cat "${body_t}"
  } >"${dest_dir}/SKILL.md"

  local asset
  for asset in "${ASSET_DIRS[@]}"; do
    if [[ -d "${src_dir}/${asset}" ]]; then
      cp -R "${src_dir}/${asset}" "${dest_dir}/${asset}"
    fi
  done

  rm -rf "${work}"

  validate_output "${dest_dir}/SKILL.md" "${id}"
}

main() {
  parse_args "$@"

  [[ -f "${MANIFEST}" ]] || die "manifest not found: ${MANIFEST}"

  local exported=() excluded=() pending=() line entry
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    if [[ -z "${line}" ]]; then
      continue
    fi
    case "${line}" in
      '!'*) excluded+=("${line#!}") ;;
      '?'*) pending+=("${line#\?}") ;;
      *) exported+=("${line}") ;;
    esac
  done <"${MANIFEST}"

  # Every skill in the repository must be classified, so a newly added skill
  # cannot silently escape the portability decision.
  local known=" ${exported[*]-} ${excluded[*]-} ${pending[*]-} " unclassified=()
  local src id
  while IFS= read -r src; do
    id="${src#"${REPO_ROOT}/plugins/"}"
    id="${id%/SKILL.md}"
    id="${id/\/skills\//\/}"
    if [[ "${known}" != *" ${id} "* ]]; then
      unclassified+=("${id}")
    fi
  done < <(find "${REPO_ROOT}/plugins" -type f -name SKILL.md | sort)

  if [[ ${#unclassified[@]} -gt 0 ]]; then
    printf 'error: skills missing from %s:\n' "${MANIFEST}" >&2
    printf '  %s\n' "${unclassified[@]}" >&2
    die "classify each as exported, ?pending, or !claude-only"
  fi

  local dest_root
  if [[ ${CHECK_MODE} -eq 1 ]]; then
    TMP_ROOT="$(mktemp -d)"
    trap cleanup EXIT
    dest_root="${TMP_ROOT}/skills"
  else
    dest_root="${OUT_DIR}/skills"
    if [[ -d "${dest_root}" && ! -f "${dest_root}/${MARKER}" ]]; then
      die "${dest_root} exists but is not generated by this script; refusing to overwrite"
    fi
    rm -rf "${dest_root}"
  fi
  mkdir -p "${dest_root}"
  : >"${dest_root}/${MARKER}"

  local failed=0 plugin skill
  if [[ ${#exported[@]} -gt 0 ]]; then
    for entry in "${exported[@]}"; do
      plugin="${entry%%/*}"
      skill="${entry#*/}"
      if ! build_skill "${plugin}" "${skill}" "${dest_root}"; then
        failed=1
      fi
    done
  fi

  [[ ${failed} -eq 0 ]] || die "portability validation failed"

  if [[ ${CHECK_MODE} -eq 1 ]]; then
    if ! diff -ru "${OUT_DIR}/skills" "${dest_root}"; then
      die "${OUT_DIR}/skills is out of date; run sync-skills.sh --out ${OUT_DIR}"
    fi
    printf 'up to date: %s skill(s)\n' "${#exported[@]}"
  else
    printf 'wrote %s skill(s) to %s\n' "${#exported[@]}" "${dest_root}"
  fi

  if [[ ${#pending[@]} -gt 0 ]]; then
    printf 'pending migration (%s):\n' "${#pending[@]}"
    printf '  %s\n' "${pending[@]}"
  fi
}

main "$@"
