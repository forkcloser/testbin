#!/usr/bin/env bash
# What each FLAC decoder program here is held to: its own part, the program
# around someone else's decoder. The bytes flac encoded come back, in the raw
# form its README names, at every depth given; the stream's parameters go to
# stderr; without arguments it prints its usage and exits 1; and an input that
# ends before its stream does is an error, which only the program can know:
# the libraries are fed bytes and never told they ended. What the library
# under it does with a stream it gets wrong or cannot read is the library's,
# and is not tested here.
#   decoder-smoke.sh <name> <directory holding it> <directory holding flac> <depths>
# The depths are one argument ("8 16 24").
set -euo pipefail

name=${1:?name of the decoder}
dir=${2:?directory holding the decoder}
flac_dir=${3:?directory holding flac}
read -r -a depths <<< "${4:?depths to round-trip}"
x=""
[ -e "${dir}/${name}.exe" ] && x=".exe"
decoder="${dir}/${name}${x}"
flac="${flac_dir}/flac${x}"

work=$(mktemp -d "${TMPDIR:-/tmp}/${name}-smoke.XXXXXX")
trap 'rm -rf "${work}"' EXIT

# Without its two arguments: the usage, on stderr, and status 1.
status=0
"${decoder}" > "${work}/stdout" 2> "${work}/stderr" || status=$?
[ "${status}" -eq 1 ] || { echo "${name}: no arguments: exit status ${status}, not 1" >&2; exit 1; }
grep -q "^usage: ${name} " "${work}/stderr" || { echo "${name}: no arguments: no usage on stderr" >&2; exit 1; }
[ ! -s "${work}/stdout" ] || { echo "${name}: no arguments: something on stdout" >&2; exit 1; }

# Any bytes are valid samples at a whole number of bytes per sample: the audio
# is the flac binary's own first bytes, a whole number of stereo frames at
# every depth (24 bytes: 2 per 8-bit frame, 4 per 16-bit, 6 per 24-bit, 8 per
# 32-bit). A regular file, not /dev/urandom, which git-bash hands a native
# head as a broken path.
size=$(wc -c < "${flac}" | tr -d ' ')
bytes=$((size / 24 * 24))
head -c "${bytes}" "${flac}" > "${work}/in.raw"
raw=(--force-raw-format --endian=little --sign=signed)
for bps in "${depths[@]}"; do
  "${flac}" -s "${raw[@]}" --channels=2 --bps="${bps}" --sample-rate=44100 -o "${work}/a-${bps}.flac" "${work}/in.raw"
  "${decoder}" "${work}/a-${bps}.flac" "${work}/out-${bps}.raw" 2> "${work}/stderr"
  cmp "${work}/in.raw" "${work}/out-${bps}.raw"
  frames=$((bytes * 8 / (bps * 2)))
  tr -d '\r' < "${work}/stderr" | grep -qx "${name}: 2 channels, ${bps} bits, 44100 Hz, ${frames} frames" ||
    { cat "${work}/stderr" >&2; echo "${name}: ${bps}-bit: the stream's parameters are not on stderr" >&2; exit 1; }
  echo "${name}: ${bps}-bit round trip through flac identical"
done

# An input that ends early is an error, as it is to `flac -d`: inside the
# stream marker, and at a frame boundary, where a library sees nothing wrong.
# The second is the whole stream cut to the length of a stream of its first
# blocks: without a seek table the two differ in their stream info alone.
head -c 3 "${work}/a-16.flac" > "${work}/marker.flac"
part=$((bytes / 2 / 16384 * 16384))
head -c "${part}" "${work}/in.raw" > "${work}/part.raw"
for stream in in part; do
  "${flac}" -s "${raw[@]}" --no-seektable --channels=2 --bps=16 --sample-rate=44100 -o "${work}/${stream}.flac" "${work}/${stream}.raw"
done
head -c "$(wc -c < "${work}/part.flac" | tr -d ' ')" "${work}/in.flac" > "${work}/boundary.flac"
for cut in marker boundary; do
  status=0
  "${decoder}" "${work}/${cut}.flac" "${work}/${cut}.raw" 2> "${work}/stderr" || status=$?
  [ "${status}" -ne 0 ] || { echo "${name}: an input cut short (${cut}): exit status 0" >&2; exit 1; }
  echo "${name}: an input cut short (${cut}) is an error"
done
