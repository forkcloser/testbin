#!/usr/bin/env bash
# Write the notices of the two pieces of Graphviz that are under terms of
# their own and ask for them beside a binary, each as its source states it.
#   notices.sh <graphviz tree> <directory to write into>
# lib/common/ellipse.c is derived from Luc Maisonobe's code (three-clause);
# lib/neatogen/randomkit.c is Jean-Sebastien Roy's Random kit (MIT), on the
# Mersenne Twister (three-clause). Both are compiled into dot.
set -euo pipefail

gv=${1:?graphviz tree}
to=${2:?directory to write into}

# ellipse.c: from the comment that names the derivation to its end.
sed -n '/^\/\* This code is derived from the Java implementation by Luc Maisonobe/,/^ \*\/$/p' \
  "${gv}/lib/common/ellipse.c" > "${to}/LICENSE.ellipse"
# randomkit.c: everything before its first include.
sed -n '/^#include/q;p' "${gv}/lib/neatogen/randomkit.c" > "${to}/LICENSE.randomkit"

# A Graphviz that moved either header would leave an empty or a cut notice.
# has <file> <words...>: every one of the words is in the file.
has() {
  local file=$1 words
  shift
  for words in "$@"; do
    grep -q "${words}" "${file}" || return 1
  done
}
if ! has "${to}/LICENSE.ellipse" 'Luc Maisonobe' 'POSSIBILITY OF SUCH DAMAGE'; then
  echo "ellipse.c: its notice is not where notices.sh reads it" >&2
  exit 1
fi
if ! has "${to}/LICENSE.randomkit" 'Jean-Sebastien Roy' 'Makoto Matsumoto' 'OTHER DEALINGS IN THE SOFTWARE'; then
  echo "randomkit.c: its notice is not where notices.sh reads it" >&2
  exit 1
fi
