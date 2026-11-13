# xz

`xz` from [XZ Utils](https://github.com/tukaani-project/xz), built from the release tarball
`pins.yaml` pins (version and sha256), with the pinned zig for linux and windows,
amd64 and arm64, and darwin arm64. liblzma is compiled into the program; there is no shared library.

The build is the full one: every filter encoder and decoder (LZMA1, LZMA2, the BCJ filters,
delta), every match finder, the three checks, the threaded encoder and decoder, the `.lz`
decoder and the MicroLZMA coders; no translations, no sandbox. The CRC code's CLMUL (amd64) and
CRC-extension (arm64) paths are compiled in and chosen at run time.

- `build.sh` compiles liblzma and the program for one zig target, straight from the sources
  upstream's `Makefile.inc` files list, without autotools or CMake.
- `config.h` stands in for the one configure generates: the same keys, valued per target from
  the compiler's own macros, so a cross build probes nothing on the host.
- `smoke.sh` compresses a fixed input with nine option sets and requires each output to match
  the sha256 recorded there, which is the same on every platform and the same as upstream's
  own build of the release writes, and to decode back to the input.

## Licence

XZ Utils is upstream's, under upstream's terms: liblzma and `xz` under the BSD Zero Clause
License (`COPYING`, `COPYING.0BSD`). Each release archive carries `COPYING`, `COPYING.0BSD` and
upstream's `AUTHORS`. The corresponding source is upstream's release tarball, pinned in
`pins.yaml` (url and sha256):
`https://github.com/tukaani-project/xz/releases/download/v<version>/xz-<version>.tar.xz`. This
directory's own files are under the repository's Apache-2.0 licence.
