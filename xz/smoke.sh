#!/usr/bin/env bash
# Compress a fixed input with nine option sets and require each output to be
# byte for byte the one every platform's build writes, and to decode back to
# the input.
#   smoke.sh <directory holding xz>
# xz's output depends on the options and liblzma alone, never on the CPU's
# CRC unit or the thread count, so one sha256 per option set holds for all five
# builds; the digests recorded here are also what upstream's own build of the
# same release writes.
set -euo pipefail

bin=${1:?directory holding xz}
x=""
[ -e "${bin}/xz.exe" ] && x=".exe"
xz=$(cd "${bin}" && pwd)/xz${x}

sha256() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

work=$(mktemp -d "${TMPDIR:-/tmp}/xz-smoke.XXXXXX")
# Leave it before removing it: windows refuses to remove a process's working
# directory.
trap 'cd / && rm -rf "${work}"' EXIT
# Relative paths from here on: a native windows binary is handed no POSIX path
# it would have to translate.
cd "${work}"
# The environment's options would change the output.
unset XZ_DEFAULTS XZ_OPT

"${xz}" --version | head -n 1

# The fixture: text with long matches, then a run of 64 Ki zero bytes. No
# /dev/zero: a native windows head reads it as a windows path.
{ seq 1 100000; printf '%65536s' '' | tr ' ' '\0'; } > fixture
want=af4f031455e96d7f307fbd10a43ec2dc3a6f064b81f26236be3e110d0e26065d
have=$(sha256 fixture)
if [ "${have}" != "${want}" ]; then
  echo "fixture: sha256 ${have}, want ${want}" >&2
  exit 1
fi

# options | sha256 of the compressed output | the options that decode it
cases=(
  "-6 -T1|3146e37778aa310b442b7843297705aade84e76e93f22ab1f6d20af45c786e45|"
  "-9e -C sha256 -T1|e13ae1b854785045c9f55cf54ee908a79a234b4e7404d0c36085a713d3e045a5|"
  "-0 -C crc32 -T1|e3dc6c8730a05de628c542f25e6aab8005e45b84cb02fc7a2fff262364797e8c|"
  "-C none -T1|fdca46079b6d694c1106b031245c10399f59b251837a1c1cce80a08b438c519b|"
  "--format=lzma -6|5efb13f404dd106caf55bbcc4c99a0216242a6709e98fef40d4943e2783866c1|--format=lzma"
  "--format=raw --lzma2=preset=6 -T1|54607509d390cccd08ee05137e31c794f4ccff8832891c82ec26ddca3b3d0366|--format=raw --lzma2=preset=6"
  "--x86 --lzma2=preset=6 -T1|c2ac017f3038a6876edf27a8e38da341f17d06483d7ddf0d85f6b0d103f5ea06|"
  "--delta=dist=4 --lzma2=preset=6 -T1|319779f6b8754d33878adf4064d537ef257a948d7b1d7bc309d3e5240f781c68|"
  "-6 -T4 --block-size=65536|bf94caa9b423a28b631e4a29420064d754ba6813ab272113157caa9736d404ce|"
)
for c in "${cases[@]}"; do
  IFS='|' read -r opts want dopts <<< "${c}"
  read -r -a o <<< "${opts}"
  read -r -a d <<< "${dopts}"
  "${xz}" "${o[@]}" -c fixture > out
  have=$(sha256 out)
  if [ "${have}" != "${want}" ]; then
    echo "xz ${opts}: sha256 ${have}, want ${want}" >&2
    exit 1
  fi
  "${xz}" ${d[@]+"${d[@]}"} -dc out > back
  cmp fixture back
  echo "xz ${opts}: the expected output, decoded back to the input"
done

# The threaded encoder split the input into blocks, and -t accepts them.
"${xz}" -6 -T4 --block-size=65536 -c fixture > blocks.xz
blocks=$("${xz}" --robot -l blocks.xz | awk '$1 == "file" { print $3 }')
if [ "${blocks}" != 10 ]; then
  echo "xz -T4 --block-size=65536: ${blocks} blocks, want 10" >&2
  exit 1
fi
"${xz}" -t blocks.xz
echo "xz -T4 --block-size=65536: 10 blocks, -t accepts them"
