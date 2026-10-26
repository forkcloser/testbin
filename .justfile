# This file is the project's own.
# Add recipes leveraging provided `do` ready-made recipes, or create your own.
# The import must be kept: it mounts every shared limen task under `just do ...`.
import '.limen/just/main.just'

# Every target a tool is built for, as os-arch; `just build` builds them all.
platforms := "linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64 windows-arm64"

# The FIRST recipe defined here becomes `just`'s default.
lint: do::lint::default
fix: do::fix::default
# Each tool built for this host and run on it.
test: flac-test
security: do::security::default

# Build every tool for every platform into $LIMEN_BUILD/dist.
build: (flac platforms)

# Build flac and metaflac for the given platforms (os-arch), each archived with
# flac's licence notices into $LIMEN_BUILD/dist/flac-<version>-<platform>.tar.gz,
# with upstream's source tarball beside them.
flac +targets: (_fetch "flac")
    #!/usr/bin/env bash
    set -euo pipefail
    export ZIG_GLOBAL_CACHE_DIR="${LIMEN_BUILD}/zig/global" ZIG_LOCAL_CACHE_DIR="${LIMEN_BUILD}/zig/local"
    version=$(limen pins get flac version)
    src="${LIMEN_BUILD}/src/flac-${version}"
    mkdir -p "${LIMEN_BUILD}/dist"
    # The GPL's corresponding source travels with the binaries: upstream's own
    # tarball, the one pins.yaml pins, published beside the archives.
    url=$(limen pins get flac url)
    cp "${LIMEN_BUILD}/src/${url##*/}" "${LIMEN_BUILD}/dist/"
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

# Fetch a pinned source into $LIMEN_BUILD/src, verify it against pins.yaml on
# every run (the tarball is published beside the binaries), and unpack it.
_fetch name:
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(limen pins get {{ name }} version)
    url=$(limen pins get {{ name }} url)
    sum=$(limen pins get {{ name }} sha256)
    dir="${LIMEN_BUILD}/src"
    archive="${dir}/${url##*/}"
    mkdir -p "${dir}"
    [ -f "${archive}" ] || curl -fsSL --retry 3 -o "${archive}" "${url}"
    if ! echo "${sum}  ${archive}" | sha256sum -c - > /dev/null; then
        echo "${archive}: sha256 does not match pins.yaml's {{ name }} ${version}" >&2
        rm -f "${archive}"
        exit 1
    fi
    rm -rf "${dir:?}/{{ name }}-${version}"
    tar -xf "${archive}" -C "${dir}"

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
