#!/usr/bin/env bash
# Round-trip arbitrary PCM through flac and back, byte for byte, and check that
# flac -t accepts the stream and metaflac reads the MD5 of the original audio.
#   smoke.sh <directory holding flac and metaflac>
set -euo pipefail

bin=${1:?directory holding flac and metaflac}
x=""
[ -e "${bin}/flac.exe" ] && x=".exe"
flac="${bin}/flac${x}"
metaflac="${bin}/metaflac${x}"

work=$(mktemp -d "${TMPDIR:-/tmp}/flac-smoke.XXXXXX")
trap 'rm -rf "${work}"' EXIT

"${flac}" --version
"${metaflac}" --version

# Any bytes are valid 16-bit samples: the audio is the flac binary's own first
# bytes, a whole number of stereo frames. A regular file, not /dev/urandom,
# which git-bash's path conversion hands to a native head as a broken path.
size=$(wc -c < "${flac}" | tr -d ' ')
head -c $((size / 4 * 4)) "${flac}" > "${work}/in.raw"
raw=(--force-raw-format --endian=little --sign=signed)
"${flac}" -s "${raw[@]}" --channels=2 --bps=16 --sample-rate=44100 -8 -o "${work}/a.flac" "${work}/in.raw"
"${flac}" -s -d "${raw[@]}" -o "${work}/out.raw" "${work}/a.flac"
cmp "${work}/in.raw" "${work}/out.raw"
"${flac}" -s -t "${work}/a.flac"

# md5sum where it exists (linux, git-bash, hermetic's coreutils); the stock
# macOS images have only md5.
if command -v md5sum > /dev/null 2>&1; then
  want=$(md5sum "${work}/in.raw" | cut -d' ' -f1)
else
  want=$(md5 -q "${work}/in.raw")
fi
got=$("${metaflac}" --show-md5sum "${work}/a.flac" | tr -d '\r')
if [ "${want}" != "${got}" ]; then
  echo "metaflac --show-md5sum: ${got}, the audio's MD5 is ${want}" >&2
  exit 1
fi
echo "flac and metaflac: round trip identical, MD5 ${got}"
