#!/usr/bin/env bash
# Encode arbitrary PCM with flac, decode it with microflac, and require the
# original bytes back, at 16, 24 and 32 bits.
#   smoke.sh <directory holding microflac> <directory holding flac>
set -euo pipefail

microflac_dir=${1:?directory holding microflac}
flac_dir=${2:?directory holding flac}
x=""
[ -e "${microflac_dir}/microflac.exe" ] && x=".exe"
microflac="${microflac_dir}/microflac${x}"
flac="${flac_dir}/flac${x}"

work=$(mktemp -d "${TMPDIR:-/tmp}/microflac-smoke.XXXXXX")
trap 'rm -rf "${work}"' EXIT

# Any bytes are valid samples at a whole number of bytes per sample: the audio
# is the flac binary's own first bytes, a whole number of stereo frames at all three
# depths (24 bytes: 4 per 16-bit frame, 6 per 24-bit, 8 per 32-bit). A regular file, not
# /dev/urandom, which git-bash hands a native head as a broken path.
size=$(wc -c < "${flac}" | tr -d ' ')
raw=(--force-raw-format --endian=little --sign=signed)
for bps in 16 24 32; do
  head -c $((size / 24 * 24)) "${flac}" > "${work}/in-${bps}.raw"
  "${flac}" -s "${raw[@]}" --channels=2 --bps="${bps}" --sample-rate=44100 -o "${work}/a-${bps}.flac" "${work}/in-${bps}.raw"
  "${microflac}" "${work}/a-${bps}.flac" "${work}/out-${bps}.raw"
  cmp "${work}/in-${bps}.raw" "${work}/out-${bps}.raw"
  echo "microflac: ${bps}-bit round trip through flac identical"
done
