#!/usr/bin/env bash
set -euo pipefail

# Put the explainer panels on a pull request.
# Usage: attach-explainer.sh [--comment] <pr> <body.md> <image>...
#
# By default the panels go into the PR description, as a section fenced by
# <!-- illustrating-pr:start --> and <!-- illustrating-pr:end --> after
# whatever the description already says. A rerun replaces that section and
# nothing else, so the pictures track the head commit while the author's
# bullets stay as written. --comment posts one comment instead: for a PR the
# user cannot edit, or when a dated record of each round is wanted.
#
# <pr> is anything gh accepts: a number, a URL, or a branch. The body is
# markdown that references every light image once as ![alt](./<file>); gh
# rewrites each reference to the uploaded asset's URL and keeps the alt text,
# so the images land under the headings the body gives them. gh matches a
# reference to an attachment by absolute path, which is why every image must
# sit in one directory and gh runs from there.
#
# A dark twin named <stem>.dark.<ext> is paired with <stem>.<ext> automatically
# and must not be referenced by hand. Twins are uploaded as plain references
# appended to the section, then the stored text is rewritten
# (theme-images.py) so each panel becomes a <picture> that follows the
# viewer's GitHub theme — gh reads references from markdown only, so a
# <picture> cannot be attached in one step.
#
# The body is prefixed with the attribution marker (scripts/lib/attribution.jq)
# so reviewers can tell an agent's text from the user's own. It is applied
# here rather than left to the caller so it cannot be forgotten.
#
# Limits mirror gh's own (internal/attachments): image types png, jpg, jpeg,
# gif, webp, svg; 10 MiB per image; 50 attachments per command. Checking them
# first means a bad file is reported before anything is uploaded.

readonly MAX_IMAGE_BYTES=$((10 * 1024 * 1024))
readonly MAX_ATTACHMENTS=50
readonly SECTION_START='<!-- illustrating-pr:start -->'
readonly SECTION_END='<!-- illustrating-pr:end -->'
# PR titles and bullets are English in this marketplace's repositories, so
# the section heading is too; the panels under it keep their own language.
readonly SECTION_HEADING='## In pictures'

usage() {
  echo "Usage: attach-explainer.sh [--comment] <pr> <body.md> <image>..." >&2
  exit 1
}

mode="description"
if [[ "${1:-}" == "--comment" ]]; then
  mode="comment"
  shift
fi
[[ $# -ge 3 ]] || usage

readonly PR="$1"
readonly BODY_FILE="$2"
shift 2

# Physical path on purpose: other agents reach this script through a
# ~/.agents/skills symlink, and ../../../scripts/lib only exists from the
# real location.
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
LIB_DIR="$(cd -- "${SCRIPT_DIR}/../../../scripts/lib" && pwd)"
readonly LIB_DIR
readonly THEME_SCRIPT="${SCRIPT_DIR}/theme-images.py"

if [[ -z "${PR}" ]]; then
  echo "Error: PR selector is empty" >&2
  exit 1
fi

if [[ ! -s "${BODY_FILE}" ]]; then
  echo "Error: body file missing or empty: ${BODY_FILE}" >&2
  exit 1
fi

if [[ $# -gt "${MAX_ATTACHMENTS}" ]]; then
  echo "Error: $# images given; gh accepts at most ${MAX_ATTACHMENTS} per command" >&2
  exit 1
fi

# Portable file size: GNU and BSD stat disagree on flags.
file_size() {
  wc -c < "$1" | tr -d ' '
}

reference_count() {
  grep -oF -- "(./$1)" "${BODY_FILE}" | wc -l | tr -d ' '
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

image_dir=""
names=()
lights=()
darks=()
for image in "$@"; do
  if [[ ! -f "${image}" ]]; then
    echo "Error: image not found: ${image}" >&2
    exit 1
  fi

  name="$(basename -- "${image}")"
  ext="${name##*.}"
  case "$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')" in
    png|jpg|jpeg|gif|webp|svg) ;;
    *)
      echo "Error: unsupported image type: ${image} (png, jpg, jpeg, gif, webp, svg)" >&2
      exit 1
      ;;
  esac

  size="$(file_size "${image}")"
  if [[ "${size}" -gt "${MAX_IMAGE_BYTES}" ]]; then
    echo "Error: ${image} is ${size} bytes; images must be at most ${MAX_IMAGE_BYTES} bytes (10 MiB)" >&2
    exit 1
  fi

  dir="$(cd -- "$(dirname -- "${image}")" && pwd)"
  if [[ -z "${image_dir}" ]]; then
    image_dir="${dir}"
  elif [[ "${dir}" != "${image_dir}" ]]; then
    echo "Error: images must share one directory; ${image} is outside ${image_dir}" >&2
    exit 1
  fi

  if contains "${name}" "${names[@]:-}"; then
    echo "Error: duplicate image name: ${name}" >&2
    exit 1
  fi
  names+=("${name}")

  if [[ "${name}" == *.dark.* ]]; then
    darks+=("${name}")
  else
    lights+=("${name}")
  fi
done

for name in "${lights[@]:-}"; do
  [[ -n "${name}" ]] || continue
  case "$(reference_count "${name}")" in
    0)
      echo "Error: ${name} is not referenced in the body as ![alt](./${name}); every image needs a heading and a reference" >&2
      exit 1
      ;;
    1) ;;
    *)
      echo "Error: ${name} is referenced more than once; one reference per image" >&2
      exit 1
      ;;
  esac
done

pairs=()
for dark in "${darks[@]:-}"; do
  [[ -n "${dark}" ]] || continue
  light="${dark%.dark.*}.${dark##*.}"
  if ! contains "${light}" "${lights[@]:-}"; then
    echo "Error: ${dark} has no light twin ${light} among the images" >&2
    exit 1
  fi
  if [[ "$(reference_count "${dark}")" -ne 0 ]]; then
    echo "Error: ${dark} is referenced in the body; a dark twin is paired with ${light} automatically, reference only the light file" >&2
    exit 1
  fi
  pairs+=("${light}=${dark}")
done

if grep -qF -- "${SECTION_START}" "${BODY_FILE}" || grep -qF -- "${SECTION_END}" "${BODY_FILE}"; then
  echo "Error: the body must not contain the section markers; the script adds them" >&2
  exit 1
fi

# gh runs from the image directory, which is usually outside any repository,
# so a bare number or branch is pinned to the repository of the current
# directory before leaving it. A URL carries its own.
repo_flag=()
if [[ "${PR}" != https://* ]]; then
  if ! owner_repo="$(GH_NO_UPDATE_NOTIFIER=1 gh repo view --json nameWithOwner --jq .nameWithOwner 2>&1)"; then
    echo "Error: PR ${PR} needs a repository; run from inside the repo or pass the PR URL (${owner_repo})" >&2
    exit 1
  fi
  repo_flag=(-R "${owner_repo}")
fi

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

# The section as uploaded: the attributed body, then the dark twins as
# references of their own so gh uploads them and rewrites their URLs; the
# second step folds them into their light panels.
readonly SECTION="${WORK_DIR}/section.md"
{
  # -r prints one newline after the string, so the file's own is trimmed first.
  jq -Rrs -L "${LIB_DIR}" 'include "attribution"; rtrimstr("\n") | attribute' "${BODY_FILE}"
  for dark in "${darks[@]:-}"; do
    [[ -n "${dark}" ]] || continue
    printf '\n![%s](./%s)\n' "${dark}" "${dark}"
  done
} > "${SECTION}"

attach_args=()
for name in "${names[@]}"; do
  attach_args+=(--attach "./${name}")
done

dark_flags=()
for pair in "${pairs[@]:-}"; do
  [[ -n "${pair}" ]] || continue
  dark_flags+=(--dark "${pair}")
done

theme() {
  local uploaded="$1" stored="$2" out="$3"
  python3 -I "${THEME_SCRIPT}" "${uploaded}" "${stored}" "${dark_flags[@]}" > "${out}"
}

if [[ "${mode}" == "comment" ]]; then
  cd "${image_dir}"
  comment_url="$(gh pr comment "${PR}" "${repo_flag[@]}" --body-file "${SECTION}" "${attach_args[@]}")"
  echo "${comment_url}"
  [[ ${#pairs[@]} -gt 0 ]] || exit 0

  if [[ ! "${comment_url}" =~ ^https://[^/]+/([^/]+)/([^/]+)/pull/[0-9]+#issuecomment-([0-9]+)$ ]]; then
    echo "Error: comment posted, but its URL could not be parsed to apply the dark twins: ${comment_url}" >&2
    exit 1
  fi
  endpoint="repos/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/issues/comments/${BASH_REMATCH[3]}"
  gh api "${endpoint}" --jq .body > "${WORK_DIR}/stored.md"
  theme "${SECTION}" "${WORK_DIR}/stored.md" "${WORK_DIR}/themed.md"
  jq -Rs '{body: .}' "${WORK_DIR}/themed.md" > "${WORK_DIR}/patch.json"
  gh api -X PATCH "${endpoint}" --input "${WORK_DIR}/patch.json" > /dev/null
  echo "themed   ${#pairs[@]} panels follow the viewer's GitHub theme"
  exit 0
fi

# Description: keep everything outside the fenced section, drop the old
# section if a previous run left one, and append the new one.
pr_json="$(gh pr view "${PR}" "${repo_flag[@]}" --json url,body)"
pr_url="$(jq -r '.url' <<< "${pr_json}")"
jq -r '.body // ""' <<< "${pr_json}" > "${WORK_DIR}/current.md"

awk -v start="${SECTION_START}" -v end="${SECTION_END}" '
  index($0, start) { skip = 1 }
  !skip { lines[++n] = $0 }
  index($0, end) { skip = 0 }
  END {
    while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
    for (i = 1; i <= n; i++) print lines[i]
  }
' "${WORK_DIR}/current.md" > "${WORK_DIR}/kept.md"

readonly UPLOAD_BODY="${WORK_DIR}/upload.md"
{
  if [[ -s "${WORK_DIR}/kept.md" ]]; then
    cat "${WORK_DIR}/kept.md"
    printf '\n'
  fi
  printf '%s\n%s\n\n' "${SECTION_START}" "${SECTION_HEADING}"
  cat "${SECTION}"
  printf '%s\n' "${SECTION_END}"
} > "${UPLOAD_BODY}"

cd "${image_dir}"
gh pr edit "${PR}" "${repo_flag[@]}" --body-file "${UPLOAD_BODY}" "${attach_args[@]}" > /dev/null
echo "${pr_url}"
[[ ${#pairs[@]} -gt 0 ]] || exit 0

gh pr view "${PR}" "${repo_flag[@]}" --json body --jq '.body' > "${WORK_DIR}/stored.md"
theme "${UPLOAD_BODY}" "${WORK_DIR}/stored.md" "${WORK_DIR}/themed.md"
gh pr edit "${PR}" "${repo_flag[@]}" --body-file "${WORK_DIR}/themed.md" > /dev/null
echo "themed   ${#pairs[@]} panels follow the viewer's GitHub theme"
