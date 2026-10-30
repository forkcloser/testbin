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
trap 'rm -rf "${work}"' EXIT
# Relative paths from here on: a native windows binary is handed no POSIX path
# it would have to translate.
cd "${work}"
cp "${fixture}" fixture.tar
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
  "plain|-b4096|8e2987618abcdaef3602b424c1219783f7058d3365699fb514d6e7ffe331364e|yes"
  "noinline|-b4096 -Enoinline_data|0493a71fae573955c0cb496d8490ce81f92ab4c27651b899ea91e80cd50958e4|yes"
  "lz4|-b4096 -zlz4|29d58f5f2237e66e2d1ec35964e138e1e6a2c3cd3d45b363d854f6af4bedbcd7|yes"
  "lz4hc|-b16384 -zlz4hc,12 -Ededupe|1b28c8f3e90ba2b4b3b9723aa368a417a415fa28dc3524b463368d10a2193633|yes"
  "deflate|-b512 -zdeflate|f0456c78f78ac023360a541a67ffb381c84de698dddef2e6dfbd2813b8714585|no"
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
    echo "DIAG ${name} size $(wc -c < "${name}.img") SDE=${SOURCE_DATE_EPOCH:-unset}" >&2
    od -A d -t x1 -v -j 1024 -N 256 "${name}.img" | sed 's/^/DIAGSB /' >&2
    size=$(wc -c < "${name}.img")
    i=0
    while [ $((i * 512)) -lt "${size}" ]; do
      echo "DIAG ${name} ${i} $(dd if="${name}.img" bs=512 skip="${i}" count=1 2> /dev/null | od -A n -t x1 -v | tr -d ' \n' | cksum | cut -d' ' -f1)" >&2
      i=$((i + 1))
    done
    if [ -x "${fsck}" ] && [ "${readable}" = yes ]; then
      rm -rf out
      "${fsck}" --extract=out --no-preserve "${name}.img" >&2 && diff -r ref out >&2 && echo "DIAG ${name} extract identical" >&2
    fi
    failed=1
    continue
  fi
  if [ -x "${fsck}" ] && [ "${readable}" = yes ]; then
    rm -rf out
    "${fsck}" --extract=out --no-preserve "${name}.img"
    diff -r ref out
    [ "$(readlink out/dir/link)" = small.txt ]
  fi
  echo "mkfs.erofs ${opts}: the expected image$([ -x "${fsck}" ] && [ "${readable}" = yes ] && echo ", extracted identical to the tar")"
done

[ -z "${failed:-}" ] || exit 1

# The tar from a pipe, as from a file: the stream path the windows patches
# change.
cat fixture.tar | "${mkfs}" "${common[@]}" -b4096 stdin.img
cmp plain.img stdin.img
echo "mkfs.erofs from a pipe: the same image as from the file"
