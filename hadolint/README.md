# hadolint

`hadolint` from [hadolint/hadolint](https://github.com/hadolint/hadolint), built for linux amd64
and arm64, static on musl, and for macOS arm64, from the commit `pins.yaml` pins: a commit of
upstream's master, not a release. A consumer runs it as an oracle against that exact commit. The binary prints the
version of upstream's last release (`Haskell Dockerfile Linter 2.15.1`), which is not the pin:
the pin is the commit, and the archive's `SOURCE` file names it.

GHC compiles for the machine it runs on, so each platform is built on a runner of it. There
is no hadolint here for windows yet: GHC has a compiler for windows amd64 and none for windows
arm64.

On macOS (`build-darwin.sh`) it is built the way upstream builds its own macOS release: the
pinned GHC and cabal-install on the host (macOS 15 or later: the build reads cabal's plan with
the system's `jq`), one `cabal build`, no container. macOS has no static C
library, so the binary is linked against five libraries the system ships (`darwin-linked`; the
build measures the list and stops when it is another), found with the system's own tools alone.
The plan is the linux one but for one flag: the `zlib` package finds the C library by name,
since macOS ships it with no pkg-config. cabal's directory is written into the binary, so the
build runs at one path on every machine. Stripped, the binary is signed again, ad hoc: an arm64
Mac runs nothing whose signature does not match it.

On linux it is built the way upstream builds its own static release, in an alpine container.
Its inputs, and how each is held:

- `versions.env`: the alpine image, by digest.
- `pins.yaml` (repository root): hadolint's source, GHC (each tarball checked against its
  release manager's PGP signature) and cabal-install, one entry an architecture.
- `apk.lock`: every alpine package the container holds once the build's own are installed, the
  linker and the assembler as much as the libraries. The image fixes what it ships; these are
  installed into it at whatever alpine serves, so the build compares and stops when one moved.
  Alpine keeps one version of a package, so a build at an old tag stops then, and says so.
- `apk-linked`: of those, the ones whose code is in the binary (musl, GMP, gcc's runtime).
  Measured, not listed: the build reads the linker's map and stops when the packages it took
  from are not exactly these.
- `cabal.project.freeze` and `cabal.project.local`: every Haskell package at one version, at
  one state of Hackage. Upstream commits no freeze file and resolves on the day of the build;
  this one is ours, and the build stops if cabal would resolve anything else.
- `build.sh` starts the container; `in-container.sh` is what runs in it. GHC compiles for the
  machine it runs on, so each architecture is built on a runner of it.
- `smoke.sh` runs the binary on a fixed Dockerfile and requires the JSON report of the one rule
  it breaks, and the licence files beside it.

Two builds of one commit give the same bytes, while alpine serves the locked packages: the
two build lanes each build it, and their archives are compared.

What the build fetches and compiles that is not hadolint's own (alpine's packages, cabal's index,
the Hackage archives and the compiled dependencies) goes to a kept directory,
`$LIMEN_BUILD/kept/hadolint/<platform>`: a second build of the same inputs compiles hadolint
alone. CI keeps it between runs under a key of the pins and every file here
(`just hadolint-kept`); a release starts with none.

## Licence

hadolint is GPL-3 (`LICENSE` in the archive), and what it is built from is linked into the
binary (all of it on linux; on macOS all but the system's own libraries), so the archive is a
GPL work: it is published to be run by tests, and nothing in this organisation
links it. Each archive carries:

- `LICENSE`, the GNU GPL version 3, and `COPYING.LESSER`, the GNU LGPL version 3, under which
  GMP is linked in.
- `NOTICES`: the licence files of what is in the binary, taken from the build's own plan (the
  libraries the executable depends on, to the end): each Hackage package's licence files from
  the top of its source archive, GHC's libraries' from GHC's release, and the texts kept in
  `licenses/` by version for what those do not carry: on linux musl, gcc's runtime exception
  and the libffi GHC links into its runtime, and on both the xxHash that GHC's runtime and `hashable` each
  compile into themselves, whose terms are in a header. A licence carried only inside a source file is found by reading, as
  that one was, not by the build.
- `SOURCE`: the offer of the corresponding source. Every component at its exact version and
  where its source is: hadolint at the commit, GHC's release, each Hackage package, and this
  recipe, which builds it again; on linux each alpine package with the commit of alpine's aports
  that built it (the same bytes while alpine serves the locked packages), on macOS the system
  libraries it is linked against, which are not in it. The three files are written by
  `notices.sh` for every platform, from what each platform's build hands it.

This directory's own files are under the repository's MIT licence.
