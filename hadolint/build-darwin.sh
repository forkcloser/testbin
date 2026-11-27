#!/usr/bin/env bash
# Build hadolint for macOS arm64, on a macOS arm64 host, the way upstream
# builds its own macOS release: the pinned GHC and cabal-install, one
# `cabal build` with -fPIC, against the libraries macOS ships. There is no
# static C library on macOS, so nothing here is a container's.
#   build-darwin.sh <source tree> <ghc tarball> <cabal-install tarball> <output directory> <kept directory>
# The tree and the two tarballs are pins.yaml's, fetched and verified by the
# recipe that calls this. The kept directory holds cabal's index, source
# archives and store: empty, the build fills it; filled by a build of the same
# inputs, the next one compiles hadolint alone.
#
# The build runs at one path on every machine (HADOLINT_ROOT): cabal's
# directory is written into the binary (each package's Paths module), so
# another path is another binary.
set -euo pipefail
export LC_ALL=C

src=${1:?source tree}
ghc=${2:?ghc tarball}
cabal=${3:?cabal-install tarball}
out=${4:?output directory}
kept=${5:?kept directory}
: "${HADOLINT_COMMIT:?the pinned commit}" "${HADOLINT_URL:?the pinned source url}"

[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || { echo "hadolint: this build runs on macOS arm64 only" >&2; exit 1; }
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src=$(cd "${src}" && pwd)
ghc=$(cd "$(dirname "${ghc}")" && pwd)/$(basename "${ghc}")
cabal=$(cd "$(dirname "${cabal}")" && pwd)/$(basename "${cabal}")
mkdir -p "${out}" "${kept}/cabal"
out=$(cd "${out}" && pwd)
kept=$(cd "${kept}" && pwd)

# /usr/bin/jq, for the plan: macOS has it from version 15.
[ -x /usr/bin/jq ] || { echo "hadolint: no /usr/bin/jq: this build needs macOS 15 or later" >&2; exit 1; }

# The root is made again for each build, so it is removed first: only one
# this build made, which it marks, and never whatever else the variable names.
root=${HADOLINT_ROOT:-/private/tmp/testbin-hadolint}
if [ -e "${root}" ] && [ ! -f "${root}/.testbin-hadolint" ]; then
  echo "hadolint: ${root} exists and is not a root this build made (no .testbin-hadolint in it): remove it yourself, or name another with HADOLINT_ROOT" >&2
  exit 1
fi
rm -rf "${root}"
mkdir -p "${root}/ghc-dist" "${root}/bin" "${root}/src"
: > "${root}/.testbin-hadolint"
ln -s "${kept}/cabal" "${root}/cabal"

# The system's own tools and nothing else from here on: GHC's installer runs
# `install` through a path it does not quote, and a developer's PATH has
# directories with a space in them.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
tar -xJf "${ghc}" -C "${root}/ghc-dist" --strip-components=1
(cd "${root}/ghc-dist" && ./configure --prefix="${root}/ghc" > "${root}/ghc-configure.log" 2>&1 && make install > "${root}/ghc-install.log" 2>&1) ||
  { tail -n 30 "${root}/ghc-configure.log" "${root}/ghc-install.log" >&2; exit 1; }
rm -rf "${root}/ghc-dist"
tar -xJf "${cabal}" -C "${root}/bin"
export PATH="${root}/ghc/bin:${root}/bin:${PATH}"
echo "toolchain: $(ghc --numeric-version), $(cabal --numeric-version)"

cp -R "${src}/." "${root}/src/"
# The freeze file and the state of Hackage are the linux build's: cabal
# resolves the same plan on macOS, and the build stops if it would not.
cp "${here}/cabal.project.local" "${here}/cabal.project.freeze" "${root}/src/"
cd "${root}/src"
# But for one flag: the freeze file has the zlib package ask pkg-config for
# the C library, and macOS ships zlib with no pkg-config and no description
# of it. Without the flag the package links the system's libz by name.
grep -q '^ *zlib .*+pkg-config' cabal.project.freeze || { echo "hadolint: the freeze file no longer sets zlib's pkg-config flag: read build-darwin.sh" >&2; exit 1; }
sed -i '' '/^ *zlib /s/+pkg-config/-pkg-config/' cabal.project.freeze
export CABAL_DIR="${root}/cabal"
# The index is fetched once: the plan is resolved at a pinned state of
# Hackage, and a kept index that does not reach it gives another plan, which
# stops the build just below.
if [ ! -f "${CABAL_DIR}/packages/hackage.haskell.org/01-index.tar" ]; then
  cabal update > "${root}/cabal-update.log" 2>&1 || { cat "${root}/cabal-update.log" >&2; exit 1; }
fi
cp cabal.project.freeze "${root}/freeze.committed"
cabal freeze > /dev/null
cmp -s cabal.project.freeze "${root}/freeze.committed" || {
  echo "hadolint: cabal resolves another plan than hadolint/cabal.project.freeze holds:" >&2
  diff "${root}/freeze.committed" cabal.project.freeze >&2 || true
  exit 1
}

started=$(date +%s)
cabal build exe:hadolint --ghc-options=-fPIC > "${root}/build.log" 2>&1 || { tail -n 60 "${root}/build.log" >&2; exit 1; }
echo "built in $(($(date +%s) - started)) s"
cp "$(cabal list-bin hadolint)" "${out}/hadolint"
# strip leaves the linker's ad-hoc signature stale, and an arm64 Mac runs no
# binary whose signature does not match it.
strip "${out}/hadolint"
codesign --force --sign - --identifier hadolint "${out}/hadolint"
chmod 0755 "${out}/hadolint"

# What the binary takes from the machine it runs on, measured: the libraries
# it is linked against are hadolint/darwin-linked's, each one macOS's own.
otool -L "${out}/hadolint" | sed -n 's/^[[:space:]]*\([^ ]*\) (.*$/\1/p' | sort > "${root}/linked.measured"
grep -v '^#' "${here}/darwin-linked" | sort > "${root}/linked.named"
cmp -s "${root}/linked.named" "${root}/linked.measured" || {
  echo "hadolint: the binary is not linked against what hadolint/darwin-linked names (-: named, +: linked):" >&2
  diff "${root}/linked.named" "${root}/linked.measured" >&2 || true
  exit 1
}

# NOTICES, COPYING.LESSER and SOURCE are every platform's (notices.sh); what
# is this one's is written here first. Of C libraries the binary holds GMP,
# the copy GHC's release builds into its integers (its version is the
# header's that release installs), and xxHash; libffi, iconv and the rest are
# macOS's own, linked against and not in the archive.
gmp_header=$(find "${root}/ghc/lib" -name ghc-gmp.h | head -n 1)
[ -n "${gmp_header}" ] || { echo "hadolint: GHC's release installs no ghc-gmp.h: is GMP still in it?" >&2; exit 1; }
gmp=$(awk '$1 == "#define" && $2 ~ /^__GNU_MP_VERSION(_MINOR|_PATCHLEVEL)?$/ { v = v sep $3; sep = "." } END { print v }' "${gmp_header}")
{
  echo "Everything below is in the hadolint binary beside this file. It is also"
  echo "linked against libraries macOS ships, which are not in it: SOURCE names"
  echo "them. hadolint's own licence is LICENSE, the GNU GPL version 3."
} > "${root}/notices.head"
: > "${root}/notices.parts"
{
  echo "The corresponding source of this hadolint binary: every component below"
  echo "is in it. Built by packcloser/testbin, whose recipe (hadolint/, at the"
  echo "tag of the release this archive belongs to) builds it again from these"
  echo "sources on macOS, and against another GMP with a GHC built against it:"
  echo "  https://github.com/packcloser/testbin"
} > "${root}/source.head"
echo "  and the GMP ${gmp} its integers are built on (libraries/ghc-bignum/gmp/gmp-tarballs/ in the same archive)," > "${root}/source.ghc"
{
  echo "Linked against, and not in the binary: these libraries of the macOS it"
  echo "runs on."
  sed 's/^/  /' "${root}/linked.named"
} > "${root}/source.tail"
NOTICES_PLAN=dist-newstyle/cache/plan.json NOTICES_RECIPE="${here}" NOTICES_OUT="${out}" NOTICES_WORK="${root}" \
  NOTICES_GHC_DOC="${root}/ghc/share/doc" NOTICES_GMP="${gmp}" \
  NOTICES_ALSO="linked against $(wc -l < "${root}/linked.named" | tr -d ' ') libraries of macOS's" \
  NOTICES_HEAD="${root}/notices.head" NOTICES_PARTS="${root}/notices.parts" NOTICES_SOURCE_HEAD="${root}/source.head" \
  NOTICES_GHC_ALSO="${root}/source.ghc" NOTICES_SOURCE_TAIL="${root}/source.tail" \
  HADOLINT_COMMIT="${HADOLINT_COMMIT}" HADOLINT_URL="${HADOLINT_URL}" sh "${here}/notices.sh"
