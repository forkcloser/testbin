#!/usr/bin/env bash
# Encode arbitrary PCM with CUETools.Flake and decode it with flac, at 16 and at
# 24 bits, requiring the original bytes back: from WAV (Flake's encoder), and
# from FLAC (Flake's decoder then its encoder); flac -t must accept Flake's
# stream.
#   smoke.sh <directory holding CUETools.Flake> <directory holding flac>
set -euo pipefail

flake_dir=${1:?directory holding CUETools.Flake}
flac_dir=${2:?directory holding flac}
x=""
[ -e "${flake_dir}/CUETools.Flake.exe" ] && x=".exe"
flake="${flake_dir}/CUETools.Flake${x}"
flac="${flac_dir}/flac${x}"

work=$(mktemp -d "${TMPDIR:-/tmp}/flake-smoke.XXXXXX")
trap 'rm -rf "${work}"' EXIT

# Any bytes are valid samples at a whole number of bytes per sample: the audio
# is the flac binary's own first bytes, a whole number of stereo frames at both
# depths (12 bytes: 4 per 16-bit frame, 6 per 24-bit).
size=$(wc -c < "${flac}" | tr -d ' ')
raw=(--force-raw-format --endian=little --sign=signed)
for bps in 16 24; do
  w="${work}/${bps}"
  mkdir -p "${w}"
  head -c $((size / 12 * 12)) "${flac}" > "${w}/in.raw"
  "${flac}" -s "${raw[@]}" --channels=2 --bps="${bps}" --sample-rate=44100 -o "${w}/a.flac" "${w}/in.raw"
  "${flac}" -s -d -o "${w}/a.wav" "${w}/a.flac"

  "${flake}" -q -o "${w}/b.flac" "${w}/a.wav"
  "${flac}" -s -t "${w}/b.flac"
  "${flac}" -s -d "${raw[@]}" -o "${w}/b.raw" "${w}/b.flac"
  cmp "${w}/in.raw" "${w}/b.raw"

  "${flake}" -q -o "${w}/c.flac" "${w}/b.flac"
  "${flac}" -s -d "${raw[@]}" -o "${w}/c.raw" "${w}/c.flac"
  cmp "${w}/in.raw" "${w}/c.raw"
  echo "CUETools.Flake: ${bps}-bit, from WAV and from FLAC, identical through flac"
done
