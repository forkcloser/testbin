# testbin

Test-only builds of C tools that other forkcloser and farcloser repositories need in
their tests. These are not supported packages: nothing here is shipped, maintained for
other uses, or covered by any compatibility promise.

## Tools

| Directory | Builds | Upstream |
|---|---|---|
| [`flac/`](flac/) | `flac`, `metaflac` | [xiph/flac](https://github.com/xiph/flac) |

Each tool's directory holds its build script and anything the build needs beside the upstream
sources, and states the upstream licence its sources, patches and binaries are under.

## How the builds work

- **Sources are pinned, never vendored.** `pins.yaml` pins each upstream release by version and
  sha256; `just build` fetches it into `.build/`, verifies it and builds from it.
- **One host builds every platform.** The C toolchain is zig (`zig cc`), pinned in
  `.hermetic/hermetic.yaml`, with the target always explicit: linux (static, musl), darwin and
  windows, amd64 and arm64, cross-compiled from any of them. No runner package manager, no
  container.
- **Third-party source only.** Everything here builds an upstream project's own sources. A tool
  that wraps an operating system's API (a decoder on CoreAudio or Media Foundation) has no
  third-party source to build and lives with the repository that uses it.
- **Every binary runs where it ships.** CI builds each platform and runs it on that platform's
  runner (`just test`); the release workflow runs the published archives themselves on all six
  platforms before attaching them.

## Using a build

A release (`vX.Y.Z`) carries `<tool>-<upstream version>-<os>-<arch>.tar.gz` per tool and
platform, `checksums.txt`, and a GitHub build provenance attestation over every asset
(`gh attestation verify <asset> --repo forkcloser/testbin`). Consume them through hermetic, like
any other pinned tool.

## Working on it

```sh
just build              # every tool, every platform, into .build/dist
just flac darwin-arm64  # one tool, the given platforms
just test               # each tool for this host, then run on it
```
