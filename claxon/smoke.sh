#!/usr/bin/env bash
# Encode arbitrary PCM with flac, decode it with claxon, and require the
# original bytes back, at 16 and at 24 bits.
#   smoke.sh <directory holding claxon> <directory holding flac>
set -euo pipefail

claxon_dir=${1:?directory holding claxon}
flac_dir=${2:?directory holding flac}
x=""
[ -e "${claxon_dir}/claxon.exe" ] && x=".exe"
claxon="${claxon_dir}/claxon${x}"
flac="${flac_dir}/flac${x}"

work=$(mktemp -d "${TMPDIR:-/tmp}/claxon-smoke.XXXXXX")
trap 'rm -rf "${work}"' EXIT

# Any bytes are valid samples at a whole number of bytes per sample: the audio
# is the flac binary's own first bytes, a whole number of stereo frames at both
# depths (12 bytes: 4 per 16-bit frame, 6 per 24-bit). A regular file, not
# /dev/urandom, which git-bash hands a native head as a broken path.
size=$(wc -c < "${flac}" | tr -d ' ')
raw=(--force-raw-format --endian=little --sign=signed)
for bps in 16 24; do
  head -c $((size / 12 * 12)) "${flac}" > "${work}/in-${bps}.raw"
  "${flac}" -s "${raw[@]}" --channels=2 --bps="${bps}" --sample-rate=44100 -o "${work}/a-${bps}.flac" "${work}/in-${bps}.raw"
  "${claxon}" "${work}/a-${bps}.flac" "${work}/out-${bps}.raw"
  cmp "${work}/in-${bps}.raw" "${work}/out-${bps}.raw"
  echo "claxon: ${bps}-bit round trip through flac identical"
done
