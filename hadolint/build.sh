#!/usr/bin/env bash
# Build hadolint for linux, static on musl, in the alpine image
# hadolint/versions.env pins by digest, as upstream's own release does.
#   build.sh <source tree> <ghc tarball> <cabal-install tarball> <linux arch> <output directory>
# The tree and the two tarballs are pins.yaml's, fetched and verified by the
# recipe that calls this. GHC compiles for the machine it runs on and nothing
# else, so the architecture is the host's: amd64 on an amd64 host, arm64 on
# an arm64 one. Everything is mounted read-only but the output directory, and
# the build runs at fixed paths inside the container, whatever the checkout's.
set -euo pipefail

src=${1:?source tree}
ghc=${2:?ghc tarball}
cabal=${3:?cabal-install tarball}
arch=${4:?linux architecture, amd64 or arm64}
out=${5:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=hadolint/versions.env
. "${here}/versions.env"
case "${BUILD_IMAGE}" in
*@sha256:*) ;;
*) echo "hadolint: the build image is not pinned by digest: ${BUILD_IMAGE}" >&2; exit 1 ;;
esac

mkdir -p "${out}"
out=$(cd "${out}" && pwd)
# Sized and timed by build-caps.sh.
# shellcheck source=scripts/build-caps.sh
. "${here}/../scripts/build-caps.sh"
capped_container --rm --platform "linux/${arch}" \
  --volume "$(cd "${src}" && pwd):/in/src:ro" \
  --volume "$(cd "$(dirname "${ghc}")" && pwd)/$(basename "${ghc}"):/in/ghc.tar.xz:ro" \
  --volume "$(cd "$(dirname "${cabal}")" && pwd)/$(basename "${cabal}"):/in/cabal.tar.xz:ro" \
  --volume "${here}:/in/recipe:ro" \
  --volume "${out}:/out" \
  --env "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:?the time of the build}" \
  --env "HADOLINT_COMMIT=${HADOLINT_COMMIT:?the pinned commit}" \
  --env "HADOLINT_URL=${HADOLINT_URL:?the pinned source url}" \
  --env "BUILD_JOBS=${build_jobs}" \
  -- "${BUILD_IMAGE}" sh /in/recipe/in-container.sh
