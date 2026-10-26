# flac

`flac` and `metaflac` from [xiph/flac](https://github.com/xiph/flac), built from the release
tarball `pins.yaml` pins (version and sha256), with the pinned zig for linux, darwin and windows,
amd64 and arm64.

- `build.sh` compiles libFLAC, the shared helpers and the two programs for one zig target.
- `config.h` stands in for the one upstream's CMake generates: the same keys, valued per target
  from the compiler's own macros, so a cross build probes nothing on the host. Ogg FLAC is left
  out (it needs libogg); the Windows builds are single-threaded (no pthreads).
- `smoke.sh` round-trips random PCM through `flac` and back, byte for byte, and checks
  `metaflac`'s MD5 of the stream.

## Licence

The sources and the binaries built from them are upstream's, under upstream's licences: the
`flac` and `metaflac` programs under the GNU GPL version 2 or later (`COPYING.GPL`), libFLAC
under the Xiph.org BSD-style licence (`COPYING.Xiph`), and some of the shared helpers compiled
into both (getopt, the replaygain code) under the GNU LGPL (`COPYING.LGPL`). Each release
archive carries the three notices and upstream's `AUTHORS`. This directory's own files are
under the repository's Apache-2.0 licence.
