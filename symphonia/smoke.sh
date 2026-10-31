#!/usr/bin/env bash
# Encode arbitrary PCM with flac, decode it with symphonia, and require the
# original bytes back, at 16 and at 24 bits.
#   smoke.sh <directory holding symphonia> <directory holding flac>
set -euo pipefail

symphonia_dir=${1:?directory holding symphonia}
flac_dir=${2:?directory holding flac}
x=""
[ -e "${symphonia_dir}/symphonia.exe" ] && x=".exe"
symphonia="${symphonia_dir}/symphonia${x}"
flac="${flac_dir}/flac${x}"

work=$(mktemp -d "${TMPDIR:-/tmp}/symphonia-smoke.XXXXXX")
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
  "${symphonia}" "${work}/a-${bps}.flac" "${work}/out-${bps}.raw"
  cmp "${work}/in-${bps}.raw" "${work}/out-${bps}.raw"
  echo "symphonia: ${bps}-bit round trip through flac identical"
done
