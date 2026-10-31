# This file is the project's own.
# Add recipes leveraging provided `do` ready-made recipes, or create your own.
# The import must be kept: it mounts every shared limen task under `just do ...`.
import '.limen/just/main.just'

# Every target a tool is built for, as os-arch; `just build` builds them all.
platforms := "linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64 windows-arm64"

# The FIRST recipe defined here becomes `just`'s default.
lint: do::lint::default do::lint::rust::default
fix: do::fix::default do::fix::rust::default
# Each tool built for this host and run on it.
test: flac-test drflac-test foxenflac-test microflac-test cscoreflac-test flake-test erofs-test claxon-test symphonia-test
security: do::security::default

# Build every tool for every platform into $LIMEN_BUILD/dist.
build: (flac platforms) (drflac platforms) (foxenflac platforms) (microflac platforms) (flake platforms) (cscoreflac platforms) (erofs platforms) (claxon platforms) (symphonia platforms)

# Build flac and metaflac for the given platforms (os-arch), each archived with
# flac's licence notices into $LIMEN_BUILD/dist/flac-<version>-<platform>.tar.gz.
flac +targets: (_fetch "flac")
    #!/usr/bin/env bash
    set -euo pipefail
    export ZIG_GLOBAL_CACHE_DIR="${LIMEN_BUILD}/zig/global" ZIG_LOCAL_CACHE_DIR="${LIMEN_BUILD}/zig/local"
    version=$(limen pins get flac version)
    src="${LIMEN_BUILD}/src/flac-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/flac/${platform}"
        rm -rf "${out}"
        flac/build.sh "${src}" "${version}" "$(just _zig-target "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="flac-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "${out}/bin/flac${x}" "${out}/bin/metaflac${x}" "${stage}/"
        cp "${src}/COPYING.GPL" "${src}/COPYING.LGPL" "${src}/COPYING.Xiph" "${src}/AUTHORS" "${stage}/"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build flac and metaflac for this host and run the round trip on them.
flac-test:
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just flac "${platform}"
    flac/smoke.sh "${LIMEN_BUILD}/flac/${platform}/bin"

# Build drflac (a FLAC decoder on dr_flac) for the given platforms, archived
# with dr_libs' licence and this repository's (main.c is ours) into
# $LIMEN_BUILD/dist/drflac-<version>-<platform>.tar.gz.
drflac +targets: (_fetch "drflac")
    #!/usr/bin/env bash
    set -euo pipefail
    export ZIG_GLOBAL_CACHE_DIR="${LIMEN_BUILD}/zig/global" ZIG_LOCAL_CACHE_DIR="${LIMEN_BUILD}/zig/local"
    version=$(limen pins get drflac version)
    src="${LIMEN_BUILD}/src/drflac-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/drflac/${platform}"
        rm -rf "${out}"
        drflac/build.sh "${src}" "$(just _zig-target "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="drflac-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "${out}/bin/drflac${x}" "${stage}/"
        cp "${src}/LICENSE" "${stage}/LICENSE.dr_libs"
        cp LICENSE "${stage}/LICENSE"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build drflac for this host and decode flac's encodings of arbitrary PCM with it.
drflac-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just drflac "${platform}"
    drflac/smoke.sh "${LIMEN_BUILD}/drflac/${platform}/bin" "${LIMEN_BUILD}/flac/${platform}/bin"

# Build foxenflac (a FLAC decoder on libfoxenflac) for the given platforms,
# archived with libfoxenflac's licence (LGPL-2.1) and this repository's (main.c
# is ours) into $LIMEN_BUILD/dist/foxenflac-<commit>-<platform>.tar.gz.
foxenflac +targets: (_fetch "foxenflac")
    #!/usr/bin/env bash
    set -euo pipefail
    export ZIG_GLOBAL_CACHE_DIR="${LIMEN_BUILD}/zig/global" ZIG_LOCAL_CACHE_DIR="${LIMEN_BUILD}/zig/local"
    version=$(limen pins get foxenflac version)
    src="${LIMEN_BUILD}/src/foxenflac-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/foxenflac/${platform}"
        rm -rf "${out}"
        foxenflac/build.sh "${src}" "$(just _zig-target "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="foxenflac-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "${out}/bin/foxenflac${x}" "${stage}/"
        cp "${src}/LICENSE" "${stage}/LICENSE.libfoxenflac"
        cp LICENSE "${stage}/LICENSE"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build foxenflac for this host and decode flac's encodings of arbitrary PCM
# with it.
foxenflac-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just foxenflac "${platform}"
    foxenflac/smoke.sh "${LIMEN_BUILD}/foxenflac/${platform}/bin" "${LIMEN_BUILD}/flac/${platform}/bin"

# Build microflac (a FLAC decoder on microFLAC) for the given platforms,
# archived with microFLAC's licence and this repository's (main.cpp is ours)
# into $LIMEN_BUILD/dist/microflac-<version>-<platform>.tar.gz.
microflac +targets: (_fetch "microflac")
    #!/usr/bin/env bash
    set -euo pipefail
    export ZIG_GLOBAL_CACHE_DIR="${LIMEN_BUILD}/zig/global" ZIG_LOCAL_CACHE_DIR="${LIMEN_BUILD}/zig/local"
    version=$(limen pins get microflac version)
    src="${LIMEN_BUILD}/src/microflac-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/microflac/${platform}"
        rm -rf "${out}"
        microflac/build.sh "${src}" "$(just _zig-target "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="microflac-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "${out}/bin/microflac${x}" "${stage}/"
        cp "${src}/LICENSE" "${stage}/LICENSE.microflac"
        cp LICENSE "${stage}/LICENSE"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build microflac for this host and decode flac's encodings of arbitrary PCM
# with it, at 16, 24 and 32 bits.
microflac-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just microflac "${platform}"
    microflac/smoke.sh "${LIMEN_BUILD}/microflac/${platform}/bin" "${LIMEN_BUILD}/flac/${platform}/bin"

# Publish CUETools.Flake for the given platforms with the pinned .NET SDK, each
# archived with upstream's four licence notices into
# $LIMEN_BUILD/dist/flake-<version>-<platform>.tar.gz.
flake +targets: (_fetch "cuetools")
    #!/usr/bin/env bash
    set -euo pipefail
    eval "$(just _dotnet)"
    version=$(limen pins get cuetools version)
    src="${LIMEN_BUILD}/src/cuetools-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/flake/${platform}"
        rm -rf "${out}"
        flake/build.sh "${src}" "$(just _dotnet-rid "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="flake-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "${out}/CUETools.Flake${x}" "${stage}/"
        cp "${src}/License.txt" "${stage}/License.txt"
        cp "${src}/CUETools.Codecs/License.txt" "${stage}/License.CUETools.Codecs.txt"
        cp "${src}/CUETools.Codecs.Flake/COPYING" "${stage}/COPYING"
        cp "${LIMEN_BUILD}/nuget/newtonsoft.json/13.0.3/LICENSE.md" "${stage}/LICENSE.Newtonsoft.Json.md"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Publish CUETools.Flake for this host and round-trip arbitrary PCM through it
# and flac.
flake-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just flake "${platform}"
    flake/smoke.sh "${LIMEN_BUILD}/flake/${platform}" "${LIMEN_BUILD}/flac/${platform}/bin"

# Build mkfs.erofs (erofs-utils, patched, linking lz4) for the given platforms,
# archived with erofs-utils' and lz4's licence notices into
# $LIMEN_BUILD/dist/erofs-<version>-<platform>.tar.gz.
erofs +targets: (_fetch "erofs-utils") (_fetch "lz4")
    #!/usr/bin/env bash
    set -euo pipefail
    export ZIG_GLOBAL_CACHE_DIR="${LIMEN_BUILD}/zig/global" ZIG_LOCAL_CACHE_DIR="${LIMEN_BUILD}/zig/local"
    version=$(limen pins get erofs-utils version)
    src="${LIMEN_BUILD}/src/erofs-utils-${version}"
    lz4="${LIMEN_BUILD}/src/lz4-$(limen pins get lz4 version)"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/erofs/${platform}"
        rm -rf "${out}"
        erofs/build.sh "${src}" "${lz4}" "${version}" "$(just _zig-target "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="erofs-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}/LICENSES"
        cp "${out}/bin/mkfs.erofs${x}" "${stage}/"
        cp "${src}/COPYING" "${stage}/"
        cp "${src}/LICENSES/GPL-2.0" "${src}/LICENSES/MIT" "${stage}/LICENSES/"
        cp "${lz4}/lib/LICENSE" "${stage}/LICENSE.lz4"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build mkfs.erofs (and fsck.erofs where it builds) for this host and run the
# image checks on it.
erofs-test:
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just erofs "${platform}"
    erofs/smoke.sh "${LIMEN_BUILD}/erofs/${platform}/bin"

# Build claxon (a FLAC decoder on the Claxon crate) for the given platforms
# through limen's Rust lane, archived with Claxon's licence and this
# repository's (src/main.rs is ours) into
# $LIMEN_BUILD/dist/claxon-<crate version>-<platform>.tar.gz.
claxon +targets:
    #!/usr/bin/env bash
    set -euo pipefail
    set -- {{ targets }}
    triples=()
    for platform in "$@"; do
        triples+=("$(just _rust-target "${platform}")")
    done
    just do build rust targets "${triples[@]}"
    version=$(just _crate-version claxon)
    licence=$(echo "${LIMEN_BUILD}"/cargo/registry/src/*/"claxon-${version}/license")
    mkdir -p "${LIMEN_BUILD}/dist"
    for platform in "$@"; do
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="claxon-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "target/$(just _rust-target "${platform}")/release/claxon${x}" "${stage}/"
        cp "${licence}" "${stage}/LICENSE.claxon"
        cp LICENSE "${stage}/LICENSE"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build claxon for this host and decode flac's encodings of arbitrary PCM with it.
claxon-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just claxon "${platform}"
    claxon/smoke.sh "target/$(just _rust-target "${platform}")/release" "${LIMEN_BUILD}/flac/${platform}/bin"

# Build symphonia (a FLAC decoder on the Symphonia crates) for the given
# platforms through limen's Rust lane, archived with the licence files of every
# crate it links and this repository's (src/main.rs is ours) into
# $LIMEN_BUILD/dist/symphonia-<crate version>-<platform>.tar.gz.
symphonia +targets:
    #!/usr/bin/env bash
    set -euo pipefail
    set -- {{ targets }}
    triples=()
    for platform in "$@"; do
        triples+=("$(just _rust-target "${platform}")")
    done
    just do build rust targets "${triples[@]}"
    version=$(just _crate-version symphonia)
    mkdir -p "${LIMEN_BUILD}/dist"
    for platform in "$@"; do
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="symphonia-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}/licences"
        cp "target/$(just _rust-target "${platform}")/release/symphonia${x}" "${stage}/"
        cp LICENSE "${stage}/LICENSE"
        for crate in $(just _crate-closure testbin-symphonia); do
            dir=$(echo "${LIMEN_BUILD}"/cargo/registry/src/*/"${crate}")
            mkdir -p "${stage}/licences/${crate}"
            found=""
            for f in "${dir}"/LICENSE* "${dir}"/LICENCE* "${dir}"/license* "${dir}"/COPYING*; do
                [ -f "${f}" ] || continue
                cp "${f}" "${stage}/licences/${crate}/"
                found=1
            done
            [ -n "${found}" ] || { echo "${crate}: no licence file in ${dir}" >&2; exit 1; }
        done
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Build symphonia for this host and decode flac's encodings of arbitrary PCM
# with it.
symphonia-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just symphonia "${platform}"
    symphonia/smoke.sh "target/$(just _rust-target "${platform}")/release" "${LIMEN_BUILD}/flac/${platform}/bin"

# Publish cscoreflac (a FLAC decoder on CSCore's) for the given platforms with
# the pinned .NET SDK, each archived with CSCore's licence and this
# repository's (Program.cs is ours) into
# $LIMEN_BUILD/dist/cscoreflac-<version>-<platform>.tar.gz.
cscoreflac +targets: (_fetch "cscore")
    #!/usr/bin/env bash
    set -euo pipefail
    eval "$(just _dotnet)"
    version=$(limen pins get cscore version)
    src="${LIMEN_BUILD}/src/cscore-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    set -- {{ targets }}
    for platform in "$@"; do
        out="${LIMEN_BUILD}/cscoreflac/${platform}"
        rm -rf "${out}"
        cscoreflac/build.sh "${src}" "$(just _dotnet-rid "${platform}")" "${out}"
        x=""
        case "${platform}" in windows-*) x=".exe" ;; esac
        name="cscoreflac-${version}-${platform}"
        stage="${LIMEN_BUILD}/stage/${name}"
        rm -rf "${stage}"
        mkdir -p "${stage}"
        cp "${out}/cscoreflac${x}" "${stage}/"
        cp "${src}/license.md" "${stage}/LICENSE.cscore.md"
        cp LICENSE "${stage}/LICENSE"
        (cd "${LIMEN_BUILD}/stage" && tar -czf "${LIMEN_BUILD}/dist/${name}.tar.gz" "${name}")
        echo "→ ${LIMEN_BUILD}/dist/${name}.tar.gz"
    done

# Publish cscoreflac for this host and decode flac's encodings of arbitrary PCM
# with it.
cscoreflac-test: flac-test
    #!/usr/bin/env bash
    set -euo pipefail
    platform=$(just _host-platform)
    just cscoreflac "${platform}"
    cscoreflac/smoke.sh "${LIMEN_BUILD}/cscoreflac/${platform}" "${LIMEN_BUILD}/flac/${platform}/bin"

# Rewrite cscoreflac/packages.lock.json from a publish of this host's platform:
# after a .NET SDK or a CSCore bump changes what the project references.
cscoreflac-lock: (_fetch "cscore")
    #!/usr/bin/env bash
    set -euo pipefail
    eval "$(just _dotnet)"
    version=$(limen pins get cscore version)
    CSCORE_LOCKED=false CSCORE_LOCK_UPDATE=true cscoreflac/build.sh "${LIMEN_BUILD}/src/cscore-${version}" \
        "$(just _dotnet-rid "$(just _host-platform)")" "${LIMEN_BUILD}/cscoreflac/lock"

# Rewrite flake/locks from a publish of this host's platform: after a .NET SDK
# or a CUETools bump changes what the projects reference.
flake-lock: (_fetch "cuetools")
    #!/usr/bin/env bash
    set -euo pipefail
    eval "$(just _dotnet)"
    version=$(limen pins get cuetools version)
    FLAKE_LOCKED=false FLAKE_LOCK_UPDATE=true flake/build.sh "${LIMEN_BUILD}/src/cuetools-${version}" \
        "$(just _dotnet-rid "$(just _host-platform)")" "${LIMEN_BUILD}/flake/lock"

# The pinned .NET SDK for this host, fetched, verified against pins.yaml and
# unpacked once; prints the environment that puts it on PATH, for `eval`. Its
# state (the CLI's home, the NuGet packages) stays under $LIMEN_BUILD.
_dotnet:
    #!/usr/bin/env bash
    set -euo pipefail
    pin="dotnet-sdk-$(just _host-platform)"
    version=$(limen pins get "${pin}" version)
    url=$(limen pins get "${pin}" url)
    sum=$(limen pins get "${pin}" sha256)
    root="${LIMEN_BUILD}/${pin}-${version}"
    if [ ! -x "${root}/dotnet" ] && [ ! -x "${root}/dotnet.exe" ]; then
        archive="${LIMEN_BUILD}/src/${url##*/}"
        mkdir -p "${LIMEN_BUILD}/src"
        [ -f "${archive}" ] || curl -fsSL --retry 3 -o "${archive}" "${url}"
        if ! echo "${sum}  ${archive}" | sha256sum -c - > /dev/null; then
            echo "${archive}: sha256 does not match pins.yaml's ${pin} ${version}" >&2
            rm -f "${archive}"
            exit 1
        fi
        rm -rf "${root}"
        mkdir -p "${root}"
        case "${archive}" in
            *.zip) unzip -q "${archive}" -d "${root}" ;;
            *) tar -xzf "${archive}" -C "${root}" ;;
        esac
    fi
    have=$(DOTNET_CLI_HOME="${LIMEN_BUILD}/dotnet-home" DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
        DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 DOTNET_MULTILEVEL_LOOKUP=0 "${root}/dotnet" --version)
    if [ "${have}" != "${version}" ]; then
        echo "${root}: dotnet ${have}, not pins.yaml's ${pin} ${version}" >&2
        exit 1
    fi
    # PATH is colon-separated: on windows, the drive's colon would split it.
    path_root=${root}
    command -v cygpath > /dev/null 2>&1 && path_root=$(cygpath -u "${root}")
    echo "export DOTNET_ROOT='${root}' PATH='${path_root}:${PATH}'"
    echo "export DOTNET_CLI_HOME='${LIMEN_BUILD}/dotnet-home' NUGET_PACKAGES='${LIMEN_BUILD}/nuget'"
    echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1"
    echo "export DOTNET_MULTILEVEL_LOOKUP=0 MSBUILDDISABLENODEREUSE=1 DOTNET_CLI_USE_MSBUILD_SERVER=0"

# The .NET runtime identifier of a platform.
_dotnet-rid platform:
    #!/usr/bin/env bash
    case "{{ platform }}" in
        linux-amd64) echo linux-x64 ;;
        linux-arm64) echo linux-arm64 ;;
        darwin-amd64) echo osx-x64 ;;
        darwin-arm64) echo osx-arm64 ;;
        windows-amd64) echo win-x64 ;;
        windows-arm64) echo win-arm64 ;;
        *) echo "unknown platform {{ platform }} (one of {{ platforms }})" >&2; exit 1 ;;
    esac

# The release notes' source section: each tool's upstream release, as pins.yaml
# pins it, the corresponding source of the binaries built from it.
release-notes:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "## Corresponding source"
    echo
    echo "Each tool's binaries are built from upstream's release, pinned in pins.yaml (url and sha256):"
    echo
    echo "- flac $(limen pins get flac version): $(limen pins get flac url)"
    echo "- dr_flac $(limen pins get drflac version): $(limen pins get drflac url)"
    echo "- libfoxenflac $(limen pins get foxenflac version): $(limen pins get foxenflac url)"
    echo "- microFLAC $(limen pins get microflac version): $(limen pins get microflac url)"
    echo "- CUETools $(limen pins get cuetools version): $(limen pins get cuetools url)"
    echo "- CSCore $(limen pins get cscore version): $(limen pins get cscore url)"
    echo "- erofs-utils $(limen pins get erofs-utils version): $(limen pins get erofs-utils url),"
    echo "  patched with this repository's erofs/patches and built with its erofs/mingw-compat"
    echo "  headers (windows) at this release's tag"
    echo "- lz4 $(limen pins get lz4 version): $(limen pins get lz4 url)"
    echo "- Claxon $(just _crate-version claxon): https://static.crates.io/crates/claxon/claxon-$(just _crate-version claxon).crate"
    echo "- Symphonia $(just _crate-version symphonia) and the crates it links, each from crates.io at the version and"
    echo "  checksum Cargo.lock records: $(just _crate-closure testbin-symphonia | tr '\n' ' ')"

# Fetch a pinned source to $LIMEN_BUILD/src/<name>-<version>.<ext>, verify it
# against pins.yaml on every run (a reused build directory keeps the tarball),
# and unpack it into $LIMEN_BUILD/src/<name>-<version>, whatever the top
# directory upstream's tarball has.
_fetch name:
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(limen pins get {{ name }} version)
    url=$(limen pins get {{ name }} url)
    sum=$(limen pins get {{ name }} sha256)
    case "${url}" in
        *.tar.xz) ext=tar.xz ;;
        *.tar.gz) ext=tar.gz ;;
        *) echo "{{ name }}: unsupported archive ${url##*/}" >&2; exit 1 ;;
    esac
    dir="${LIMEN_BUILD}/src"
    archive="${dir}/{{ name }}-${version}.${ext}"
    mkdir -p "${dir}"
    [ -f "${archive}" ] || curl -fsSL --retry 3 -o "${archive}" "${url}"
    if ! echo "${sum}  ${archive}" | sha256sum -c - > /dev/null; then
        echo "${archive}: sha256 does not match pins.yaml's {{ name }} ${version}" >&2
        rm -f "${archive}"
        exit 1
    fi
    rm -rf "${dir:?}/{{ name }}-${version}"
    mkdir -p "${dir}/{{ name }}-${version}"
    tar -xf "${archive}" -C "${dir}/{{ name }}-${version}" --strip-components=1

# The Rust target of a platform: musl on linux (static); on windows the GNU ABI
# for amd64 and its LLVM flavour for arm64, the one Rust ships for it.
_rust-target platform:
    #!/usr/bin/env bash
    case "{{ platform }}" in
        linux-amd64) echo x86_64-unknown-linux-musl ;;
        linux-arm64) echo aarch64-unknown-linux-musl ;;
        darwin-amd64) echo x86_64-apple-darwin ;;
        darwin-arm64) echo aarch64-apple-darwin ;;
        windows-amd64) echo x86_64-pc-windows-gnu ;;
        windows-arm64) echo aarch64-pc-windows-gnullvm ;;
        *) echo "unknown platform {{ platform }} (one of {{ platforms }})" >&2; exit 1 ;;
    esac

# The version Cargo.lock locks a crate at.
_crate-version crate:
    #!/usr/bin/env bash
    set -euo pipefail
    awk -v crate='{{ crate }}' '$0 == "name = \"" crate "\"" { getline; gsub(/version = |"/, ""); print; exit }' Cargo.lock

# Every registry crate a workspace member links, as <name>-<version>, from
# Cargo.lock: its dependencies, theirs, and so on. Build-time dependencies are
# among them only if the lock lists them as normal ones, which it does not
# distinguish, so the closure can be wider than the binary, never narrower.
_crate-closure member:
    #!/usr/bin/env bash
    set -euo pipefail
    awk -v root='{{ member }}' '
        /^\[\[package\]\]/ { name = ""; indeps = 0; next }
        /^name = / { name = $3; gsub(/"/, "", name); next }
        /^version = / && name != "" { gsub(/"/, "", $3); version[name] = $3; next }
        /^source = "registry/ { registry[name] = 1; next }
        /^dependencies = \[/ { indeps = 1; next }
        indeps && /^\]/ { indeps = 0; next }
        indeps { dep = $1; gsub(/[",]/, "", dep); deps[name] = deps[name] " " dep; next }
        END {
            queue[1] = root; n = 1; seen[root] = 1
            for (i = 1; i <= n; i++) {
                k = split(deps[queue[i]], d, " ")
                for (j = 1; j <= k; j++) if (!(d[j] in seen)) { seen[d[j]] = 1; queue[++n] = d[j] }
            }
            for (c in seen) if (c in registry) print c "-" version[c]
        }' Cargo.lock | sort

# The zig target of a platform: musl on linux (static), the GNU ABI on windows.
_zig-target platform:
    #!/usr/bin/env bash
    case "{{ platform }}" in
        linux-amd64) echo x86_64-linux-musl ;;
        linux-arm64) echo aarch64-linux-musl ;;
        darwin-amd64) echo x86_64-macos ;;
        darwin-arm64) echo aarch64-macos ;;
        windows-amd64) echo x86_64-windows-gnu ;;
        windows-arm64) echo aarch64-windows-gnu ;;
        *) echo "unknown platform {{ platform }} (one of {{ platforms }})" >&2; exit 1 ;;
    esac

# This host's platform, as os-arch. In CI, RUNNER_OS and RUNNER_ARCH are the
# truth: Git for Windows' arm64 build ships an x86_64 bash, so uname and
# PROCESSOR_ARCHITECTURE report amd64 there. Elsewhere the pinned zig's own
# native target says what the machine is.
_host-platform:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${RUNNER_OS:-}" ] && [ -n "${RUNNER_ARCH:-}" ]; then
        os=${RUNNER_OS}
        machine=${RUNNER_ARCH}
    else
        native=$(zig env | sed -n -E 's/^ *\.target = "([^"]*)".*/\1/p')
        machine=${native%%-*}
        os=${native#*-}
        os=${os%%[.-]*}
    fi
    case "${os}" in
        Linux | linux) os=linux ;;
        macOS | macos) os=darwin ;;
        Windows | windows) os=windows ;;
        *) echo "unsupported host ${os}" >&2; exit 1 ;;
    esac
    case "${machine}" in
        X64 | x86_64) arch=amd64 ;;
        ARM64 | aarch64) arch=arm64 ;;
        *) echo "unsupported architecture ${machine}" >&2; exit 1 ;;
    esac
    echo "${os}-${arch}"
