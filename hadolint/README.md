# hadolint

`hadolint` from [hadolint/hadolint](https://github.com/hadolint/hadolint), built for linux amd64
and arm64, static on musl, from the commit `pins.yaml` pins: a commit of upstream's master, not
a release. A consumer runs it as an oracle against that exact commit. The binary prints the
version of upstream's last release (`Haskell Dockerfile Linter 2.15.1`), which is not the pin:
the pin is the commit, and the archive's `SOURCE` file names it.

There is no hadolint here for macOS or windows. An oracle is needed on one platform, and linux
is the one upstream's static build exists for: one container recipe covers both architectures
and every input of it can be held. A macOS binary would be another build (Apple's toolchain, no
static C library, about twice the time on a runner), and GHC has no compiler for windows arm64.

It is built the way upstream builds its own static release, in an alpine container. Its inputs,
and how each is held:

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

hadolint is GPL-3 (`LICENSE` in the archive), and the binary is statically linked, so the
archive is a GPL work: it is published to be run by tests, and nothing in this organisation
links it. Each archive carries:

- `LICENSE`, the GNU GPL version 3, and `COPYING.LESSER`, the GNU LGPL version 3, under which
  GMP is linked in.
- `NOTICES`: the licence files of what is in the binary, taken from the build's own plan (the
  libraries the executable depends on, to the end): each Hackage package's licence files from
  the top of its source archive, GHC's libraries' from GHC's release, and the texts kept in
  `licenses/` by version for what those do not carry: musl, gcc's runtime exception, the
  libffi GHC links into its runtime, and the xxHash that GHC's runtime and `hashable` each
  compile into themselves, whose terms are in a header. A licence carried only inside a source file is found by reading, as
  that one was, not by the build.
- `SOURCE`: the offer of the corresponding source. Every component at its exact version and
  where its source is: hadolint at the commit, GHC's release, each Hackage package, each alpine
  package with the commit of alpine's aports that built it, and this recipe, which builds it
  again, to the same bytes while alpine serves the locked packages.

This directory's own files are under the repository's Apache-2.0 licence.
