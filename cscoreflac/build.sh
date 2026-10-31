#!/usr/bin/env bash
# Publish cscoreflac for one .NET runtime identifier, self-contained, as a
# single file: Program.cs, this directory's own, around CSCore's FLAC decoder,
# compiled from an unpacked filoe/cscore tree (cscoreflac.csproj lists the
# upstream files; none is edited).
#   build.sh <source tree> <runtime identifier> <output directory>
# The SDK is DOTNET_ROOT's: the pinned one, which the recipe unpacks. The
# restore is locked against packages.lock.json unless CSCORE_LOCKED=false; with
# CSCORE_LOCK_UPDATE=true as well it rewrites it (`just cscoreflac-lock`).
set -euo pipefail

src=${1:?source tree}
rid=${2:?runtime identifier}
out=${3:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src=$(cd "${src}" && pwd)
mkdir -p "${out}"
out=$(cd "${out}" && pwd)
# dotnet is a native program on windows: hand it paths it can read.
if command -v cygpath > /dev/null 2>&1; then
  here=$(cygpath -m "${here}")
  src=$(cygpath -m "${src}")
  out=$(cygpath -m "${out}")
fi

# One in-process MSBuild node, no build servers: nothing outlives the build,
# and the build needs no inter-process pipes.
dotnet=${DOTNET_ROOT:?the pinned .NET SDK}/dotnet
"${dotnet}" publish "${here}/cscoreflac.csproj" \
  -c Release -r "${rid}" --self-contained \
  -p:PublishSingleFile=true \
  -p:CscoreSource="${src}" \
  -p:CscoreLocked="${CSCORE_LOCKED:-true}" \
  -p:RestoreForceEvaluate="${CSCORE_LOCK_UPDATE:-false}" \
  -p:UseSharedCompilation=false \
  --disable-build-servers -nodeReuse:false -m:1 \
  -o "${out}"
