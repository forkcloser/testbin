#!/usr/bin/env bash
# Build mkfs.erofs for one zig target from unpacked erofs-utils and lz4 trees,
# and fsck.erofs beside it for the tests where it builds (not windows).
#   build.sh <erofs-utils tree> <lz4 tree> <version> <zig target> <output directory>
# The trees are the release tarballs pins.yaml pins, fetched, verified and
# freshly unpacked by the recipe that calls this; the erofs-utils tree is
# patched here with patches/. Every target is cross-compiled with the pinned
# zig; the target is always explicit, never "native", so the host's own SDK is
# never consulted.
set -euo pipefail

src=${1:?erofs-utils tree}
lz4=${2:?lz4 tree}
version=${3:?version}
target=${4:?zig target}
out=${5:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work="${out}/obj"
mkdir -p "${work}" "${out}/bin"

# The recipe unpacks a fresh tree for each build: patch it once.
if [ ! -e "${src}/.patched" ]; then
  for p in "${here}"/patches/*.patch; do
    patch -s -d "${src}" -p1 < "${p}"
  done
  touch "${src}/.patched"
fi

# As configure would: lib/ on the include path, NDEBUG (debug is off by
# default), 64-bit offsets.
cflags=(
  -target "${target}" -O2 -std=gnu11
  -D_FILE_OFFSET_BITS=64 -DNDEBUG
  -DHAVE_CONFIG_H "-DPACKAGE_VERSION=\"${version}\""
  -I "${here}" -I "${src}/include" -I "${src}/lib" -I "${lz4}/lib"
)
exe=""
libs=(-lpthread)
case "${target}" in
*-windows-*)
  # The compat headers stand in for the POSIX surface MinGW lacks;
  # posix_compat.h is force-included into every translation unit.
  cflags+=(-D_GNU_SOURCE -I "${here}/mingw-compat" -include posix_compat.h)
  exe=".exe"
  libs=()
  ;;
*-macos*)
  cflags+=(-I "${here}/darwin-compat")
  ;;
esac

# lib/Makefile.am's liberofs sources for this configuration: lz4 and lz4hc,
# the built-in deflate compressor, the bundled xxhash, multi-threading where
# there are pthreads, the nbd backend on linux.
lib=(
  config io cache super inode xattr exclude namei data compress compressor zmap
  decompress compress_hints hashmap sha256 blobchunk dir fragments dedupe
  uuid_unparse uuid tar block_list rebuild diskbuf bitops dedupe_ext vmdk
  metabox global importer base64 compressor_lz4 compressor_lz4hc kite_deflate
  compressor_deflate xxhash remotes/oci remotes/docker_config gzran
)
case "${target}" in
*-windows-*) ;;
*) lib+=(workqueue) ;;
esac
case "${target}" in
*-linux-*) lib+=(backends/nbd) ;;
esac

for name in "${lib[@]}"; do
  zig cc "${cflags[@]}" -c "${src}/lib/${name}.c" -o "${work}/lib-${name//\//-}.o"
done
# lz4's own build compiles the library at -O3.
for name in lz4 lz4hc; do
  zig cc -target "${target}" -O3 -c "${lz4}/lib/${name}.c" -o "${work}/lz4-${name}.o"
done

zig cc "${cflags[@]}" -c "${src}/mkfs/main.c" -o "${work}/mkfs.o"
zig cc -target "${target}" -o "${out}/bin/mkfs.erofs${exe}" \
  "${work}/mkfs.o" "${work}"/lib-*.o "${work}"/lz4-*.o ${libs[@]+"${libs[@]}"}

# fsck.erofs extracts what mkfs.erofs wrote, for the smoke test; it needs more
# of POSIX than the windows patches provide, so it is not built there.
case "${target}" in
*-windows-*) ;;
*)
  zig cc "${cflags[@]}" -c "${src}/fsck/main.c" -o "${work}/fsck.o"
  zig cc -target "${target}" -o "${out}/bin/fsck.erofs" \
    "${work}/fsck.o" "${work}"/lib-*.o "${work}"/lz4-*.o "${libs[@]}"
  ;;
esac
