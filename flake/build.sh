#!/usr/bin/env bash
# Publish CUETools.Flake for one .NET runtime identifier from an unpacked
# gchudov/cuetools.net tree, self-contained, as a single file.
#   build.sh <source tree> <runtime identifier> <output directory>
# The SDK is DOTNET_ROOT's: the pinned one, which the recipe unpacks.
# The restore is locked against locks/ unless FLAKE_LOCKED=false; with
# FLAKE_LOCK_UPDATE=true as well it rewrites them (`just flake-lock`).
# Upstream's projects target end-of-life frameworks and reference each other
# for a shared plugins directory; the global TargetFrameworks property and this
# directory's two MSBuild files make a standalone net10.0 command of them
# without editing upstream's files.
set -euo pipefail

src=${1:?source tree}
rid=${2:?runtime identifier}
out=${3:?output directory}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Absolute: the publish runs from inside the source tree.
src=$(cd "${src}" && pwd)
mkdir -p "${out}"
out=$(cd "${out}" && pwd)
# dotnet is a native program on windows: hand it paths it can read.
if command -v cygpath > /dev/null 2>&1; then
  here=$(cygpath -m "${here}")
  src=$(cygpath -m "${src}")
  out=$(cygpath -m "${out}")
fi

cp "${here}/Directory.Build.props" "${src}/"

# One in-process MSBuild node, no build servers: nothing outlives the build,
# and the build needs no inter-process pipes.
dotnet=${DOTNET_ROOT:?the pinned .NET SDK}/dotnet
(cd "${src}" && "${dotnet}" publish CUETools.Flake/CUETools.Flake.csproj \
  -c Release -f net10.0 -r "${rid}" --self-contained \
  -p:TargetFrameworks=net10.0 \
  -p:PublishSingleFile=true \
  -p:FlakeLockDir="${here}/locks" \
  -p:FlakeLocked="${FLAKE_LOCKED:-true}" \
  -p:RestoreForceEvaluate="${FLAKE_LOCK_UPDATE:-false}" \
  -p:CustomAfterMicrosoftCommonTargets="${here}/standalone.targets" \
  -p:UseSharedCompilation=false \
  --disable-build-servers -nodeReuse:false -m:1 \
  -o "${out}")
