#!/usr/bin/env bash
# Build drflac for one zig target from an unpacked mackron/dr_libs tree.
#   build.sh <source tree> <zig target> <output directory>
# dr_flac is a single header; main.c, this directory's own, is the program
# around it. The target is always explicit, never "native", so the host's own
# SDK is never consulted.
set -euo pipefail

src=${1:?source tree}
target=${2:?zig target}
out=${3:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "${out}/bin"

exe=""
case "${target}" in
*-windows-*) exe=".exe" ;;
esac

zig cc -target "${target}" -O2 -std=c99 -I "${src}" \
  -o "${out}/bin/drflac${exe}" "${here}/main.c" -lm
