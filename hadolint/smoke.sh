#!/usr/bin/env bash
# Require hadolint to run, to name its version, and to report as JSON the one
# rule a fixed Dockerfile breaks.
#   smoke.sh <directory holding hadolint>
set -euo pipefail

bin=${1:?directory holding hadolint}
hadolint=$(cd "${bin}" && pwd)/hadolint

"${hadolint}" --version

work=$(mktemp -d "${TMPDIR:-/tmp}/hadolint-smoke.XXXXXX")
trap 'rm -rf "${work}"' EXIT
printf 'FROM debian\nRUN echo hello\n' > "${work}/Dockerfile"
# hadolint exits 1 when it has something to report.
"${hadolint}" --format json "${work}/Dockerfile" > "${work}/out.json" || true
cat "${work}/out.json"
grep -q '"code":"DL3006"' "${work}/out.json" || { echo "hadolint did not report DL3006 for an untagged image" >&2; exit 1; }

# Beside the binary, in an archive and in the build's output alike: its
# licence, the notices of what is linked into it, and the offer of its source.
for file in NOTICES SOURCE COPYING.LESSER; do
  [ -s "${bin}/${file}" ] || { echo "no ${file} beside hadolint" >&2; exit 1; }
done
grep -q '^GMP .*, the GNU Multiple Precision Arithmetic Library$' "${bin}/NOTICES" || { echo "NOTICES does not say GMP is linked in" >&2; exit 1; }
grep -q 'hackage.haskell.org/package/' "${bin}/SOURCE" || { echo "SOURCE names no Hackage package" >&2; exit 1; }
# What only a package's Setup needs is not in the binary, and not in SOURCE:
# xml-conduit's asks for cabal-doctest, which nothing links.
if grep -q 'cabal-doctest' "${bin}/SOURCE" "${bin}/NOTICES"; then
  echo "SOURCE or NOTICES names cabal-doctest, which only a Setup uses" >&2
  exit 1
fi
grep -q '^xxHash, which GHC ' "${bin}/NOTICES" || { echo "NOTICES has no part for the xxHash compiled into the binary" >&2; exit 1; }

case "$(uname -s)" in
  Linux)
    grep -q 'gitlab.alpinelinux.org/alpine/aports' "${bin}/SOURCE" || { echo "SOURCE does not say where the alpine packages' sources are" >&2; exit 1; }
    # Static: nothing of the host's is loaded.
    if command -v file > /dev/null; then
      file -b "${hadolint}" | grep -q 'statically linked' || { echo "hadolint is not statically linked" >&2; exit 1; }
    fi
    ;;
  Darwin)
    # Not static, which macOS has no way to be: SOURCE says what of the
    # system's it is linked against.
    grep -q '^  /usr/lib/libSystem' "${bin}/SOURCE" || { echo "SOURCE does not name the macOS libraries hadolint is linked against" >&2; exit 1; }
    ;;
esac
echo "hadolint: runs, reports DL3006 as JSON"
