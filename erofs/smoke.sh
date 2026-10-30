#!/usr/bin/env bash
# Make EROFS images from testdata/fixture.tar with mkfs.erofs and require each
# to be byte for byte the image every platform's build writes; where
# fsck.erofs sits beside it, also extract each image and require the tar's
# own files back.
#   smoke.sh <directory holding mkfs.erofs>
# A tar fixes every name, mode, owner and time, and -T0 and -U fix the rest,
# so an image depends on mkfs.erofs alone: one sha256 per option set holds for
# all six builds. The block size is always explicit, since mkfs.erofs's default
# is the host's page size.
set -euo pipefail

bin=${1:?directory holding mkfs.erofs}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
x=""
[ -e "${bin}/mkfs.erofs.exe" ] && x=".exe"
mkfs=$(cd "${bin}" && pwd)/mkfs.erofs${x}
fsck=$(cd "${bin}" && pwd)/fsck.erofs
fixture="${here}/testdata/fixture.tar"

sha256() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

work=$(mktemp -d "${TMPDIR:-/tmp}/erofs-smoke.XXXXXX")
# Leave it before removing it: windows refuses to remove a process's working
# directory.
trap 'cd / && rm -rf "${work}"' EXIT
# Relative paths from here on: a native windows binary is handed no POSIX path
# it would have to translate.
cd "${work}"
cp "${fixture}" fixture.tar
# SOURCE_DATE_EPOCH, when set, overrides -T.
unset SOURCE_DATE_EPOCH
# mkfs.erofs makes its scratch files in $TMPDIR (/tmp without it): a native
# windows binary needs a windows path there.
if command -v cygpath > /dev/null 2>&1; then
  TMPDIR=$(cygpath -m "${work}")
  export TMPDIR
fi

"${mkfs}" -V | head -n 1

common=(-T0 -U 6f8d1b52-6c5e-4b0a-9d1c-2b6f0d3e4a71 --quiet --tar=f)
# name | options | sha256 of the image | whether fsck.erofs can read it back
# (the deflate decompressor needs zlib, which this build leaves out).
cases=(
  "plain|-b4096|b8cd2965f6d9b87b4f851af8b8e5e576cf5fbb2967f1eb2fb02159adf6d22a0d|yes"
  "noinline|-b4096 -Enoinline_data|0222f0a597cbbf7c3cf6e80f2532c6ad011dc60882639caaaf14af39d6768ba6|yes"
  "lz4|-b4096 -zlz4|e28e3ad0f5ed6c79c49569136a267b32c3d019c03cf028c1068734c6ed150c83|yes"
  "lz4hc|-b16384 -zlz4hc,12 -Ededupe|215d19f1bf35a106c9934c729fcd0f6096249f7fe1cbcedfa37ca57a99ea5674|yes"
  "deflate|-b512 -zdeflate|499572aad78d062d54a8b25b0b6926c6498e98bdc4fdda9e0f43ce16bdeb108c|no"
)

if [ -x "${fsck}" ]; then
  mkdir ref
  tar -xf fixture.tar -C ref
fi

for c in "${cases[@]}"; do
  IFS='|' read -r name opts want readable <<< "${c}"
  read -r -a o <<< "${opts}"
  "${mkfs}" "${common[@]}" "${o[@]}" "${name}.img" fixture.tar
  have=$(sha256 "${name}.img")
  if [ "${have}" != "${want}" ]; then
    echo "${name} (${opts}): sha256 ${have}, want ${want}" >&2
    exit 1
  fi
  if [ -x "${fsck}" ] && [ "${readable}" = yes ]; then
    rm -rf out
    "${fsck}" --extract=out --no-preserve "${name}.img"
    diff -r ref out
    [ "$(readlink out/dir/link)" = small.txt ]
  fi
  echo "mkfs.erofs ${opts}: the expected image$([ -x "${fsck}" ] && [ "${readable}" = yes ] && echo ", extracted identical to the tar")"
done

# The tar from a pipe, as from a file: the stream path the windows patches
# change.
cat fixture.tar | "${mkfs}" "${common[@]}" -b4096 stdin.img
cmp plain.img stdin.img
echo "mkfs.erofs from a pipe: the same image as from the file"
