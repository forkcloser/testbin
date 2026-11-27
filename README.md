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
| [`erofs/`](erofs/) | `mkfs.erofs`, `fsck.erofs` (not windows) | [erofs/erofs-utils](https://github.com/erofs/erofs-utils), with [lz4](https://github.com/lz4/lz4) and [libdeflate](https://github.com/ebiggers/libdeflate) |
| [`xz/`](xz/) | `xz` | [tukaani-project/xz](https://github.com/tukaani-project/xz) |
| [`graphviz/`](graphviz/) | `dot` | [graphviz](https://gitlab.com/graphviz/graphviz), with [expat](https://github.com/libexpat/libexpat) |
| [`hadolint/`](hadolint/) | `hadolint` (linux and macOS arm64; a GPL-3 binary, published to be run by tests and linked by nothing) | [hadolint/hadolint](https://github.com/hadolint/hadolint), at a commit, not a release |
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
  musl) and windows, amd64 and arm64, and darwin arm64, cross-compiled from any of them. No runner
  package manager, no container. One exception: `hadolint` is a Haskell program, which nothing
  here cross-compiles; it is built on a runner of each platform it has, in a container on
  linux and on the host on macOS, and not yet for windows ([`hadolint/`](hadolint/)).
- **Third-party source only.** Everything here builds an upstream project's own sources,
  patched only where a platform needs it (`erofs/patches`, for windows); a library that ships
  no program gets the smallest one around it that exercises it (`drflac`, `foxenflac`,
  `microflac`, `claxon`, `symphonia`). A tool that wraps an operating system's API has no
  third-party source to build and lives with the repository that uses it.
- **Every binary runs where it ships.** CI builds each platform and runs it on that platform's
  runner (`just test`); the release workflow runs the published archives themselves on all five
  platforms before attaching them.
- **A build is its commit's.** Built again from the same commit, on another machine and at
  another time, every archive is the same bytes, so a published one can be checked by building
  it. CI builds every group twice, on two runners at once, and compares the archives' checksums
  (the `reproducible` job). The two share a checkout path and restore the same caches (zig's
  compiled runtime libraries among them), so a path that reached a binary, or something a cache
  carried into one, would not show there; a release is built with no cache.
  (`hadolint` for as long as Alpine serves the packages its lock names: after that its build
  stops, and says which moved.)
  Nothing of the build is recorded. The binaries carry no debug information and no symbols (they
  name the build's directories); a Rust binary's paths are remapped and a .NET one's mapped; a
  windows executable's time stamp is a hash of its content; and every archive entry has the
  commit's time, owner and group 0 with no name, and comes in name order
  (`scripts/reproducible.sh`, `scripts/archive.sh`). The commit's time is read from git: a
  build from a source tarball sets `SOURCE_DATE_EPOCH` to it, or its archives are dated 0.

## Using a build

A release (`vX.Y.Z`) carries `<tool>-<os>-<arch>.tar.gz` per tool and platform,
`checksums.txt`, and a GitHub build provenance attestation over every asset
(`gh attestation verify <asset> --repo forkcloser/testbin`). The archive is the contract: it
holds one directory of its own name, with the tool's binaries (`.exe` on windows) and the
licence notices of what they are built from. Its name carries no upstream version, so a
consumer's pin moves with the tag alone: a repository consumes a tool through its `pins.yaml`,
one entry per platform its tests run on, with
`verify: github-attestation forkcloser/testbin forkcloser/testbin/.github/workflows/release.yaml`,
and a recipe that fetches the host's archive, checks it against the pinned sha256 and puts the
binary on the PATH its tests see, under the name the tests expect. Which upstream version a
release carries is in its notes: the corresponding source of each tool's binaries is upstream's
release, pinned in `pins.yaml` (url and sha256), e.g. flac's
`https://github.com/xiph/flac/releases/download/<version>/flac-<version>.tar.xz`; each release's
notes link it, and the patches a tool's directory applies, at the release's tag.

## Working on it

```sh
just build              # every tool, every platform, into .build/dist
just build-group xz     # the named tools, every platform (the workflows build one group of tools a runner)
just flac darwin-arm64  # one tool, the given platforms (also: just drflac, flake, erofs, xz, graphviz, claxon, symphonia …)
just test               # each tool for this host, then run on it
just converge           # rewrite the NuGet lock files, after a .NET SDK, CSCore or CUETools bump
```
