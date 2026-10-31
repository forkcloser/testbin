#!/usr/bin/env bash
# Build microflac for one zig target from an unpacked esphome-libs/micro-flac
# tree: main.cpp, this directory's own, around microFLAC's decoder sources,
# built without the Ogg demuxer (a git submodule the release tarball does not
# carry). The target is always explicit, never "native", so the host's own SDK
# is never consulted.
#   build.sh <source tree> <zig target> <output directory>
set -euo pipefail

src=${1:?source tree}
target=${2:?zig target}
out=${3:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work="${out}/obj"
mkdir -p "${work}" "${out}/bin"

exe=""
case "${target}" in
*-windows-*) exe=".exe" ;;
esac

# cmake/sources.cmake's decoder sources and the shared ones; the encoder's are
# left out.
for name in crc frame_header pcm_packing flac_decoder decorrelation lpc; do
  zig c++ -target "${target}" -O2 -std=c++14 -DMICRO_FLAC_DISABLE_OGG \
    -I "${src}/include" -I "${src}/src" -c "${src}/src/${name}.cpp" -o "${work}/${name}.o"
done
zig c++ -target "${target}" -O2 -std=c++14 -DMICRO_FLAC_DISABLE_OGG \
  -I "${src}/include" -c "${here}/main.cpp" -o "${work}/main.o"
zig c++ -target "${target}" -o "${out}/bin/microflac${exe}" "${work}"/*.o
