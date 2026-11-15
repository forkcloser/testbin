#!/usr/bin/env bash
# Build dot for one zig target from an unpacked Graphviz tree and an unpacked
# expat tree: the layout engines, the core renderers and expat compiled into
# the program, as upstream's dot_static, no plugin loaded at run time.
#   build.sh <graphviz tree> <expat tree> <graphviz version> <expat version> <zig target> <output directory>
# The trees are the release tarballs pins.yaml pins, fetched and verified by
# the recipe that calls this, and compiled as they ship: this dot is the
# reference other repositories hold their own output to. No configure run:
# the two headers beside this script stand in for its output.
set -euo pipefail
export LC_ALL=C

gv=${1:?graphviz tree}
expat=${2:?expat tree}
version=${3:?graphviz version}
expat_version=${4:?expat version}
target=${5:?zig target}
out=${6:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/jobs.sh
. "${here}/../scripts/jobs.sh"
# shellcheck source=scripts/reproducible.sh
. "${here}/../scripts/reproducible.sh"
work="${out}/obj"
mkdir -p "${work}" "${out}/bin"

# Graphviz's libraries, each compiled whole, and its three built-in plugins.
libs=(
  lib/ast lib/cdt lib/cgraph lib/circogen lib/common lib/dotgen lib/edgepaint
  lib/expr lib/fdpgen lib/gvc lib/label lib/ortho lib/osage lib/pack
  lib/patchwork lib/pathplan lib/rbtree lib/sfdpgen lib/sfio lib/sparse
  lib/twopigen lib/util lib/xdot
  plugin/core plugin/dot_layout plugin/neato_layout plugin/vt
)
# lib/neatogen by name: it also holds the sources of engines this
# configuration leaves out (ipsep and its constraint solver, which are C++).
neatogen=(
  adjust bfs call_tri circuit closest compute_hierarchy conjgrad
  constrained_majorization constraint delaunay dijkstra edges embed_graph
  geometry heap hedges info kkutils legal lu matinv matrix_ops multispline
  neatoinit neatosplines opt_arrangement overlap pca poly quad_prog_solve
  randomkit sgd site smart_ini_x solve stress stuff voronoi
)

# -ffile-prefix-map: Graphviz's asserts carry __FILE__, the path a source was
# compiled from.
common=(
  -target "${target}" -O2 "${repro_cflags[@]}"
  "-ffile-prefix-map=${gv}=graphviz" "-ffile-prefix-map=${expat}=expat"
  "-ffile-prefix-map=${here}=testbin"
)
cflags=(
  "${common[@]}" -std=gnu17 -D_GNU_SOURCE -D_DARWIN_C_SOURCE
  "-DGRAPHVIZ_VERSION=\"${version}\"" -DDEMAND_LOADING=0
  -I "${here}" -I "${gv}" -I "${gv}/lib" -I "${expat}/lib"
)
for dir in "${libs[@]}" lib/neatogen lib/mingle lib/vpsc lib/topfish; do
  cflags+=(-I "${gv}/${dir}")
done
# expat's own headers only: its tree ships an expat_config.h, which the one
# beside this script replaces.
expat_cflags=(
  "${common[@]}" -std=c99 "-DEXPAT_VERSION=\"${expat_version}\""
  -DXML_STATIC -I "${here}" -I "${expat}/lib"
)
exe=""
ldlibs=(-lm)
case "${target}" in
*-windows-*)
  cflags+=(-D__USE_MINGW_ANSI_STDIO=1)
  exe=".exe"
  ldlibs=()
  expat_random=random_rand_s
  ;;
*-macos*) expat_random=random_arc4random_buf ;;
*) expat_random=random_getrandom ;;
esac

# One object per source, named with its directory: basenames repeat across
# the libraries. The compilers run side by side; join before linking.
for dir in "${libs[@]}"; do
  for source in "${gv}/${dir}"/*.c; do
    # A test program of its own, with a main.
    [ "${source##*/}" != test_red_black_tree.c ] || continue
    name=${source##*/}
    spawn zig cc "${cflags[@]}" -c "${source}" -o "${work}/${dir//\//-}-${name%.c}.o"
  done
done
spawn zig cc "${cflags[@]}" -c "${gv}/lib/sfio/Sfio_f/_sfslen.c" -o "${work}/lib-sfio-f-_sfslen.o"
for name in "${neatogen[@]}"; do
  spawn zig cc "${cflags[@]}" -c "${gv}/lib/neatogen/${name}.c" -o "${work}/lib-neatogen-${name}.o"
done
for name in xmlparse xmltok xmlrole xcs "${expat_random}"; do
  spawn zig cc "${expat_cflags[@]}" -c "${expat}/lib/${name}.c" -o "${work}/expat-${name}.o"
done
spawn zig cc "${cflags[@]}" -c "${gv}/cmd/dot/dot.c" -o "${work}/cmd-dot.o"
# The table of built-in plugins, the one C++ source.
spawn zig c++ "${cflags[@]/-std=gnu17/-std=gnu++17}" -c "${gv}/cmd/dot/dot_builtins.cpp" -o "${work}/cmd-dot_builtins.o"
join

zig c++ -target "${target}" "${repro_ldflags[@]}" -o "${out}/bin/dot${exe}" \
  "${work}"/*.o ${ldlibs[@]+"${ldlibs[@]}"}
