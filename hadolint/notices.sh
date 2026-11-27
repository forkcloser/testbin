#!/bin/sh
# hadolint's NOTICES, COPYING.LESSER and SOURCE, written from the build's own
# plan: the half of the build every platform shares. What a platform alone
# knows comes in files it writes first:
#   NOTICES_HEAD         the first lines of NOTICES
#   NOTICES_PARTS        a line "<title>:<file of hadolint/licenses>" for each
#                        C library in the binary but GMP and xxHash
#   NOTICES_SOURCE_HEAD  the first lines of SOURCE, down to this repository
#   NOTICES_GHC_ALSO     what else of GHC's release is in the binary
#   NOTICES_SOURCE_TAIL  the last section of SOURCE: the platform's own
# and in variables: NOTICES_PLAN (cabal's plan.json), NOTICES_RECIPE (this
# directory), NOTICES_OUT, NOTICES_WORK (a scratch directory), NOTICES_GHC_DOC
# (where GHC's release keeps each library's LICENSE), NOTICES_GMP (the GMP in
# the binary), NOTICES_ALSO (the end of the line that counts what is in the
# binary), CABAL_DIR, HADOLINT_COMMIT and HADOLINT_URL.
set -eu
export LC_ALL=C
plan=${NOTICES_PLAN:?}
recipe=${NOTICES_RECIPE:?}
out=${NOTICES_OUT:?}
work=${NOTICES_WORK:?}
ghc_doc=${NOTICES_GHC_DOC:?}
gmp=${NOTICES_GMP:?}
commit=${HADOLINT_COMMIT:?the pinned hadolint commit}
url=${HADOLINT_URL:?the pinned hadolint source url}
: "${CABAL_DIR:?}" "${NOTICES_ALSO:?}"
for given in "${NOTICES_HEAD:?}" "${NOTICES_PARTS:?}" "${NOTICES_SOURCE_HEAD:?}" "${NOTICES_GHC_ALSO:?}" "${NOTICES_SOURCE_TAIL:?}"; do
  [ -f "${given}" ] || { echo "hadolint: no ${given}" >&2; exit 1; }
done

# What the binary is made of, from the build's own plan: the libraries the
# executable depends on, and theirs, to the end; GHC's (pre-existing) and
# Hackage's (configured). The plan also holds what only the tests need, the
# tools that run during the build, and what a package's own Setup needs,
# none of which is linked: of a package cabal builds whole, the libraries'
# dependencies alone are followed.
tab=$(printf '\t')
# shellcheck disable=SC2016 # jq's variables, not the shell's
jq -r '
  ."install-plan" as $plan
  | ($plan | map({key: .id, value: .}) | from_entries) as $unit
  | def close: . as $seen
      | ([$seen[] | $unit[.] | ((.depends // []) + [(.components // {}) | to_entries[] | select(.key == "lib" or (.key | startswith("lib:"))) | (.value.depends // [])[]])[]] + $seen | unique) as $next
      | if ($next | length) == ($seen | length) then $seen else ($next | close) end;
  [$plan[] | select(."pkg-name" == "hadolint" and ."component-name" == "exe:hadolint") | .id]
  | if length == 0 then error("no exe:hadolint in the plan") else . end
  | close | .[] | $unit[.] | select(."pkg-name" != "hadolint")
  | [.type, ."pkg-name", ."pkg-version"] | @tsv' \
  "${plan}" | sort -u > "${work}/units"
[ -s "${work}/units" ] || { echo "hadolint: the build plan names no package" >&2; exit 1; }
echo "in the binary: $(grep -c '^pre-existing' "${work}/units") packages of GHC's, $(grep -c '^configured' "${work}/units") of Hackage's, and ${NOTICES_ALSO}"
ghc_version=$(ghc --numeric-version)
# xxHash is compiled into the binary twice, by GHC's runtime (rts/Hash.c) and
# by hashable, each from a header that carries its terms where no licence
# file does. One text, kept by the versions of whatever compiles it in: with
# hashable gone it is still the runtime's, under another name, read again.
hashable=$(awk -F "${tab}" '$2 == "hashable" { print $3 }' "${work}/units")
xxhash="LICENSE-xxhash-in-ghc-${ghc_version}"
xxhash_of="GHC ${ghc_version}'s runtime compiles"
if [ -n "${hashable}" ]; then
  xxhash="${xxhash}-and-hashable-${hashable}"
  xxhash_of="GHC ${ghc_version}'s runtime and hashable ${hashable} each compile"
fi
echo "xxHash, which ${xxhash_of} in:${xxhash}" | cat "${NOTICES_PARTS}" - > "${work}/parts"
while read -r part; do
  text=${part##*:}
  [ -s "${recipe}/licenses/${text}" ] || { echo "hadolint: no hadolint/licenses/${text} for a library the binary links" >&2; exit 1; }
done < "${work}/parts"
[ -s "${recipe}/licenses/LICENSE-lgpl-3.0" ] || { echo "hadolint: no hadolint/licenses/LICENSE-lgpl-3.0" >&2; exit 1; }

# NOTICES: each package's own licence files, as its source carries them; a
# package with none stops the build.
{
  cat "${NOTICES_HEAD}"
  echo
  echo "================================================================"
  echo "GMP ${gmp}, the GNU Multiple Precision Arithmetic Library"
  echo "================================================================"
  echo
  echo "This program uses GMP, which is linked into it. GMP and its use are"
  echo "covered by the GNU Lesser General Public License version 3, a copy of"
  echo "which is COPYING.LESSER beside this file; the GNU General Public"
  echo "License it refers to is LICENSE. Where GMP's source is, and how this"
  echo "program is built again against another GMP, is in SOURCE."
  while read -r part; do
    echo
    echo "================================================================"
    echo "${part%%:*}"
    echo "================================================================"
    echo
    cat "${recipe}/licenses/${part##*:}"
  done < "${work}/parts"
  while IFS="${tab}" read -r type name version; do
    echo
    echo "================================================================"
    echo "${name} ${version}"
    echo "================================================================"
    echo
    if [ "${type}" = pre-existing ]; then
      # GHC's runtime has no directory of its own: it is under GHC's licence.
      [ "${name}" != rts ] || { name=ghc; version=${ghc_version}; }
      file=$(find "${ghc_doc}" -path "*/${name}-${version}/LICENSE" | head -n 1)
      [ -n "${file}" ] || { echo "hadolint: GHC ships no LICENSE for ${name} ${version}" >&2; exit 1; }
      cat "${file}"
    else
      sdist="${CABAL_DIR}/packages/hackage.haskell.org/${name}/${version}/${name}-${version}.tar.gz"
      [ -f "${sdist}" ] || { echo "hadolint: no source archive for ${name} ${version} in cabal's store" >&2; exit 1; }
      files=$(tar -tzf "${sdist}" | awk -F/ 'NF == 2 && tolower($2) ~ /licen[sc]e|copying|notice|copyright/' | sort)
      [ -n "${files}" ] || { echo "hadolint: ${name} ${version} carries no licence file" >&2; exit 1; }
      for file in ${files}; do
        tar -xzOf "${sdist}" "${file}"
      done
    fi
  done < "${work}/units"
} > "${out}/NOTICES"
cp "${recipe}/licenses/LICENSE-lgpl-3.0" "${out}/COPYING.LESSER"

# SOURCE: the offer of the corresponding source, in the archive itself, every
# component at its exact version and where its source is.
{
  cat "${NOTICES_SOURCE_HEAD}"
  echo
  echo "hadolint, GPL-3, at commit ${commit}:"
  echo "  ${url}"
  echo
  echo "GHC ${ghc_version}: its runtime and these libraries of its release:"
  awk -F "${tab}" '$1 == "pre-existing" { printf "  %s %s\n", $2, $3 }' "${work}/units"
  cat "${NOTICES_GHC_ALSO}"
  echo "  all in https://downloads.haskell.org/~ghc/${ghc_version}/ghc-${ghc_version}-src.tar.xz"
  echo
  echo "From Hackage, each at the version hadolint/cabal.project.freeze holds:"
  awk -F "${tab}" '$1 == "configured" { printf "  https://hackage.haskell.org/package/%s-%s/%s-%s.tar.gz\n", $2, $3, $2, $3 }' "${work}/units"
  echo
  cat "${NOTICES_SOURCE_TAIL}"
} > "${out}/SOURCE"
