#!/usr/bin/env bash
# Require dot to name its Graphviz release, to write a fixed graph back in
# canonical form byte for byte, and to lay it out.
#   smoke.sh <directory holding dot> [<graphviz version>]
# -Tcanon is the parser and the writer alone, so its output is the same text
# on every platform. A layout's coordinates are floating point and are not
# held to a digest here: that the dot engine runs to the end is the check.
# With a version, `dot -V` must name it: a consumer's oracle runs only against
# the release it pins.
set -euo pipefail

bin=${1:?directory holding dot}
version=${2:-}
x=""
[ -e "${bin}/dot.exe" ] && x=".exe"
dot=$(cd "${bin}" && pwd)/dot${x}

work=$(mktemp -d "${TMPDIR:-/tmp}/graphviz-smoke.XXXXXX")
# Leave it before removing it: windows refuses to remove a process's working
# directory.
trap 'cd / && rm -rf "${work}"' EXIT
# Relative paths from here on: a native windows binary is handed no POSIX path
# it would have to translate.
cd "${work}"

# -V writes to stderr.
said=$("${dot}" -V 2>&1 | tr -d '\r')
echo "${said}"
# A version is held whole, up to the space before the build date: 16.1 would
# otherwise pass for 16.1.1.
case "${said}" in
"dot - graphviz version ${version} ("*) ;;
"dot - graphviz version "[0-9]*) [ -z "${version}" ] ;;
*) false ;;
esac || {
  echo "dot -V: expected graphviz version ${version:-<a number>}" >&2
  exit 1
}

# An HTML-like label, so that expat is in the path; a cluster and an edge
# label, so that canon has something to reorder.
cat > fixture.dot <<'GRAPH'
digraph G { a -> b; b -> c [label="x"]; subgraph cluster_0 { c; d } n [label=<<b>h</b>>] }
GRAPH
cat > want.canon <<'GRAPH'
digraph G {
	node [label="\N"];
	subgraph cluster_0 {
		c;
		d;
	}
	n	[label=<<b>h</b>>];
	a -> b;
	b -> c	[label=x];
}
GRAPH
"${dot}" -Tcanon fixture.dot | tr -d '\r' > got.canon
if ! cmp -s want.canon got.canon; then
  echo "dot -Tcanon: not the expected text:" >&2
  cat got.canon >&2
  exit 1
fi
echo "dot -Tcanon: the expected text"

"${dot}" -Tplain fixture.dot | tr -d '\r' > got.plain
nodes=$(grep -c '^node ' got.plain)
if [ "${nodes}" != 5 ] || ! tail -n 1 got.plain | grep -qx stop; then
  echo "dot -Tplain: expected 5 nodes and a closing stop:" >&2
  cat got.plain >&2
  exit 1
fi
echo "dot -Tplain: 5 nodes laid out"
