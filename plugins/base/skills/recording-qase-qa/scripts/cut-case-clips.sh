#!/usr/bin/env bash
set -euo pipefail

# Cut one take into an MP4 per case.
# Usage: cut-case-clips.sh <marks file> <video> [output dir]
#
# The marks file holds one "<label> <epoch seconds>" line per mark, written
# while the take was filmed: "start" before the recording starts, a case's ID
# before its chapter, "end" after the last case. A case runs from its mark to
# the next one and lands in <output dir>/case-<id>.mp4 (default: beside the
# marks file). Prints the clips' paths.
#
# Marks are written before the command they announce, so the time that command
# takes to reach the browser cancels out between two marks.

readonly USAGE='Usage: cut-case-clips.sh <marks file> <video> [output dir]'
readonly MARKS="${1:?${USAGE}}"
readonly VIDEO="${2:?${USAGE}}"
OUT_DIR="${3:-$(dirname -- "${MARKS}")}"
readonly OUT_DIR

if [[ ! -r "${MARKS}" ]]; then
  echo "Error: Cannot read the marks file: ${MARKS}" >&2
  exit 1
fi
if [[ ! -r "${VIDEO}" ]]; then
  echo "Error: Cannot read the video: ${VIDEO}" >&2
  exit 1
fi
if [[ ! -d "${OUT_DIR}" ]]; then
  echo "Error: Not a directory: ${OUT_DIR}" >&2
  exit 1
fi
if ! command -v ffmpeg > /dev/null; then
  echo 'Error: ffmpeg is not on PATH' >&2
  exit 1
fi

# "<id> <from> <to>" per case, in seconds from the start mark.
cuts="$(awk '
  function fail(message) {
    printf "Error: %s line %d: %s\n", FILENAME, NR, message > "/dev/stderr"
    failed = 1
    exit 1
  }
  !/^[A-Za-z0-9_-]+ [0-9]+(\.[0-9]+)?$/ { fail("expected \"<label> <seconds>\"") }
  NR == 1 && $1 != "start" { fail("the first mark is not start") }
  NR > 1 && label == "end" { fail("a mark follows end") }
  NR > 1 && $2 <= from { fail("the clock does not advance") }
  seen[$1]++ { fail("the label repeats") }
  NR == 1 { start = $2 }
  NR > 2 { printf "%s %.2f %.2f\n", label, from - start, $2 - start }
  { label = $1; from = $2 }
  END {
    if (failed) exit 1
    if (label != "end") {
      printf "Error: %s: the last mark is not end\n", FILENAME > "/dev/stderr"
      exit 1
    }
  }
' "${MARKS}")"

if [[ -z "${cuts}" ]]; then
  echo "Error: No case between start and end: ${MARKS}" >&2
  exit 1
fi

while read -r id from to; do
  out="${OUT_DIR}/case-${id}.mp4"
  # -nostdin: ffmpeg would otherwise read the rest of the rows as keystrokes.
  ffmpeg -nostdin -v error -y -ss "${from}" -to "${to}" -i "${VIDEO}" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "${out}"
  printf '%s\n' "${out}"
done <<< "${cuts}"
