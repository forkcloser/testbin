#!/usr/bin/env bash
# Build flac and metaflac for one zig target from an unpacked xiph/flac tree.
#   build.sh <source tree> <version> <zig target> <output directory>
# The tree is the release tarball pins.yaml pins, fetched and verified by the
# recipe that calls this. Every target is cross-compiled with the pinned zig;
# the target is always explicit, never "native", so the host's own SDK is
# never consulted.
set -euo pipefail

src=${1:?source tree}
version=${2:?version}
target=${3:?zig target}
out=${4:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work="${out}/obj"
mkdir -p "${work}" "${out}/bin"

exe=""
case "${target}" in
*-windows-*) exe=".exe" ;;
esac

cflags=(
  -target "${target}" -O2 -std=gnu99
  -DHAVE_CONFIG_H -DFLAC__NO_DLL "-DPACKAGE_VERSION=\"${version}\""
  -I "${here}" -I "${src}/include" -I "${src}/src/libFLAC/include"
)
# libFLAC's own flags, as src/libFLAC/CMakeLists.txt sets them.
libflac_flags=(-fassociative-math -fno-signed-zeros -fno-trapping-math -freciprocal-math)

libflac=(
  bitmath bitreader bitwriter cpu crc fixed fixed_intrin_sse2 fixed_intrin_ssse3
  fixed_intrin_sse42 fixed_intrin_avx2 float format lpc lpc_intrin_neon
  lpc_intrin_sse2 lpc_intrin_sse41 lpc_intrin_avx2 lpc_intrin_fma md5 memory
  metadata_iterators metadata_object stream_decoder stream_encoder
  stream_encoder_intrin_sse2 stream_encoder_intrin_ssse3
  stream_encoder_intrin_avx2 stream_encoder_framing window
)
share=(
  getopt/getopt getopt/getopt1 grabbag/alloc grabbag/cuesheet grabbag/file
  grabbag/picture grabbag/replaygain grabbag/seektable grabbag/snprintf
  replaygain_analysis/replaygain_analysis
  replaygain_synthesis/replaygain_synthesis utf8/charset utf8/iconvert utf8/utf8
)
case "${target}" in
*-windows-*) share+=(win_utf8_io/win_utf8_io) ;;
esac
flac=(analyze decode encode foreign_metadata main local_string_utils utils vorbiscomment)
metaflac=(
  main operations operations_shorthand_cuesheet operations_shorthand_picture
  operations_shorthand_seektable operations_shorthand_streaminfo
  operations_shorthand_vorbiscomment options usage utils
)

# compile <object prefix> <source dir> <names...> [-- <extra flags...>]: one
# object per source, named with its directory so equal basenames do not clash.
compile() {
  local prefix=$1 dir=$2
  shift 2
  local names=() extra=()
  while [ $# -gt 0 ]; do
    if [ "$1" = -- ]; then
      shift
      extra=("$@")
      break
    fi
    names+=("$1")
    shift
  done
  local name
  for name in "${names[@]}"; do
    zig cc "${cflags[@]}" ${extra[@]+"${extra[@]}"} -c "${src}/${dir}/${name}.c" \
      -o "${work}/${prefix}-${name//\//-}.o"
  done
}

compile libflac src/libFLAC "${libflac[@]}" -- "${libflac_flags[@]}"
compile share src/share "${share[@]}"
compile flac src/flac "${flac[@]}"
compile metaflac src/metaflac "${metaflac[@]}"

zig cc -target "${target}" -o "${out}/bin/flac${exe}" \
  "${work}"/libflac-*.o "${work}"/share-*.o "${work}"/flac-*.o -lm
zig cc -target "${target}" -o "${out}/bin/metaflac${exe}" \
  "${work}"/libflac-*.o "${work}"/share-*.o "${work}"/metaflac-*.o -lm
