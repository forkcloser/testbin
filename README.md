# testbin

Test-only builds of C tools that other forkcloser and farcloser repositories need in
their tests. These are not supported packages: nothing here is shipped, maintained for
other uses, or covered by any compatibility promise.

## Tools

| Directory | Builds | Upstream |
|---|---|---|
| [`flac/`](flac/) | `flac`, `metaflac` | [xiph/flac](https://github.com/xiph/flac) |
| [`drflac/`](drflac/) | `drflac`, a FLAC decoder on dr_flac | [mackron/dr_libs](https://github.com/mackron/dr_libs) |
| [`foxenflac/`](foxenflac/) | `foxenflac`, a FLAC decoder on libfoxenflac | [astoeckel/libfoxenflac](https://github.com/astoeckel/libfoxenflac) |
| [`microflac/`](microflac/) | `microflac`, a FLAC decoder on microFLAC | [esphome-libs/micro-flac](https://github.com/esphome-libs/micro-flac) |
| [`flake/`](flake/) | `CUETools.Flake`, CUETools' FLAC encoder | [gchudov/cuetools.net](https://github.com/gchudov/cuetools.net) |
| [`cscoreflac/`](cscoreflac/) | `cscoreflac`, a FLAC decoder on CSCore's | [filoe/cscore](https://github.com/filoe/cscore) |
| [`erofs/`](erofs/) | `mkfs.erofs` | [erofs/erofs-utils](https://github.com/erofs/erofs-utils), with [lz4](https://github.com/lz4/lz4) |
| [`claxon/`](claxon/) | `claxon`, a FLAC decoder on Claxon | [ruuda/claxon](https://github.com/ruuda/claxon) |
| [`symphonia/`](symphonia/) | `symphonia`, a FLAC decoder on Symphonia | [pdeljanov/Symphonia](https://github.com/pdeljanov/Symphonia) |

Each tool's directory holds its build script and anything the build needs beside the upstream
sources, and states the upstream licence its sources, patches and binaries are under.

## How the builds work

- **Sources are pinned, never vendored.** `pins.yaml` pins each upstream release by version and
  sha256; `just build` fetches it into `.build/`, verifies it and builds from it. A Rust tool's
  crate is pinned by `Cargo.toml` and locked by checksum in `Cargo.lock`.
- **One host builds every platform.** The C toolchain is zig (`zig cc`), pinned in
  `.hermetic/hermetic.yaml`, and the Rust tools link through it (limen's Rust lanes, the
  toolchain pinned by `rust-toolchain.toml`), with the target always explicit: linux (static,
  musl), darwin and windows, amd64 and arm64, cross-compiled from any of them. No runner
  package manager, no container.
- **Third-party source only.** Everything here builds an upstream project's own sources,
  patched only where a platform needs it (`erofs/patches`, for windows); a library that ships
  no program gets the smallest one around it that exercises it (`drflac`, `foxenflac`,
  `microflac`, `claxon`, `symphonia`). A tool that wraps an operating system's API has no
  third-party source to build and lives with the repository that uses it.
- **Every binary runs where it ships.** CI builds each platform and runs it on that platform's
  runner (`just test`); the release workflow runs the published archives themselves on all six
  platforms before attaching them.

## Using a build

A release (`vX.Y.Z`) carries `<tool>-<upstream version>-<os>-<arch>.tar.gz` per tool and
platform, `checksums.txt`, and a GitHub build provenance attestation over every asset
(`gh attestation verify <asset> --repo forkcloser/testbin`). Consume them through hermetic, like
any other pinned tool. The corresponding source of each tool's binaries is upstream's release,
pinned in `pins.yaml` (url and sha256), e.g. flac's
`https://github.com/xiph/flac/releases/download/<version>/flac-<version>.tar.xz`; each release's
notes link it, and the patches a tool's directory applies, at the release's tag.

## Working on it

```sh
just build              # every tool, every platform, into .build/dist
just flac darwin-arm64  # one tool, the given platforms (also: just drflac, flake, erofs, claxon, symphonia …)
just test               # each tool for this host, then run on it
```
