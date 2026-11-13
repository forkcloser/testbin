#!/usr/bin/env bash
# Build xz for one zig target from an unpacked XZ Utils tree: liblzma compiled
# into the program, no shared library.
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
# shellcheck source=scripts/jobs.sh
. "${here}/../scripts/jobs.sh"
work="${out}/obj"
mkdir -p "${work}" "${out}/bin"

# As upstream's CMake build: the system extensions on every platform (each is
# inert where it means nothing), 64-bit off_t, NDEBUG, config.h's values.
cflags=(
  -target "${target}" -O2 -std=gnu11
  -D_GNU_SOURCE -D_DARWIN_C_SOURCE -D_FILE_OFFSET_BITS=64
  -DHAVE_CONFIG_H "-DPACKAGE_VERSION=\"${version}\""
  -I "${here}" -I "${src}/src/common" -I "${src}/src/liblzma/api"
  -I "${src}/src/liblzma/common" -I "${src}/src/liblzma/check"
  -I "${src}/src/liblzma/lz" -I "${src}/src/liblzma/lzma"
  -I "${src}/src/liblzma/rangecoder" -I "${src}/src/liblzma/delta"
  -I "${src}/src/liblzma/simple"
)
exe=""
libs=(-lpthread)
case "${target}" in
*-windows-*)
  # MinGW's own stdio for the C99 formats xz's messages use.
  cflags+=(-D__USE_MINGW_ANSI_STDIO=1)
  exe=".exe"
  libs=()
  ;;
esac

# src/liblzma/*/Makefile.inc's sources for this configuration: every encoder,
# decoder and match finder, the three checks, threads, the .lz decoder, the
# MicroLZMA coders; the table-driven CRCs (not HAVE_SMALL), the C ones, with
# the CLMUL and ARM64 paths chosen at run time where config.h enables them.
liblzma=(
  common/common common/block_util common/easy_preset common/filter_common
  common/hardware_physmem common/index common/stream_flags_common
  common/string_conversion common/vli_size
  common/hardware_cputhreads common/outqueue
  common/alone_encoder common/block_buffer_encoder common/block_encoder
  common/block_header_encoder common/easy_buffer_encoder common/easy_encoder
  common/easy_encoder_memusage common/filter_buffer_encoder
  common/filter_encoder common/filter_flags_encoder common/index_encoder
  common/stream_buffer_encoder common/stream_encoder
  common/stream_flags_encoder common/vli_encoder common/stream_encoder_mt
  common/microlzma_encoder
  common/alone_decoder common/auto_decoder common/block_buffer_decoder
  common/block_decoder common/block_header_decoder
  common/easy_decoder_memusage common/file_info common/filter_buffer_decoder
  common/filter_decoder common/filter_flags_decoder common/index_decoder
  common/index_hash common/stream_buffer_decoder common/stream_decoder
  common/stream_flags_decoder common/vli_decoder common/stream_decoder_mt
  common/microlzma_decoder common/lzip_decoder
  check/check check/crc32_fast check/crc64_fast check/sha256
  lz/lz_decoder lz/lz_encoder lz/lz_encoder_mf
  lzma/lzma_encoder_presets lzma/lzma_encoder lzma/lzma_encoder_optimum_fast
  lzma/lzma_encoder_optimum_normal lzma/fastpos_table lzma/lzma_decoder
  lzma/lzma2_encoder lzma/lzma2_decoder
  rangecoder/price_table
  delta/delta_common delta/delta_encoder delta/delta_decoder
  simple/simple_coder simple/simple_encoder simple/simple_decoder
  simple/x86 simple/powerpc simple/ia64 simple/arm simple/armthumb
  simple/arm64 simple/sparc simple/riscv
)
# The tuklib helpers liblzma carries, under its own symbol prefix.
liblzma_tuklib=(tuklib_physmem tuklib_cpucores)
# src/xz/Makefile.am's sources, with the tuklib helpers the program carries.
xz=(
  args coder file_io hardware main message mytime options sandbox signals
  suffix util list
)
xz_tuklib=(
  tuklib_open_stdxxx tuklib_progname tuklib_exit tuklib_mbstr_fw
  tuklib_mbstr_nonprint tuklib_mbstr_width tuklib_mbstr_wrap
)

# compile <object prefix> <source dir> <names...> [-- <extra flags...>]: one
# object per source, named with its directory so equal basenames do not clash.
# The compilers run side by side; join before linking.
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
    spawn zig cc "${cflags[@]}" ${extra[@]+"${extra[@]}"} -c "${src}/${dir}/${name}.c" \
      -o "${work}/${prefix}-${name//\//-}.o"
  done
}

compile liblzma src/liblzma "${liblzma[@]}" -- -DTUKLIB_SYMBOL_PREFIX=lzma_
compile liblzma src/common "${liblzma_tuklib[@]}" -- -DTUKLIB_SYMBOL_PREFIX=lzma_
compile xz src/xz "${xz[@]}"
compile xz src/common "${xz_tuklib[@]}"
join

zig cc -target "${target}" -o "${out}/bin/xz${exe}" \
  "${work}"/liblzma-*.o "${work}"/xz-*.o ${libs[@]+"${libs[@]}"}
