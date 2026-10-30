# erofs

`mkfs.erofs`, from [erofs-utils](https://github.com/erofs/erofs-utils)' release tag `pins.yaml`
pins (`v<version>`, sha256), linking [lz4](https://github.com/lz4/lz4) from its pinned tag,
built with the pinned zig for linux, darwin and windows, amd64 and arm64.

The build is configured as forkcloser/erofs's image-backed tests need it: lz4 and lz4hc, the
built-in deflate compressor, no other compression library (zlib, liblzma, libdeflate, libzstd),
no libuuid, libselinux, curl, openssl, libxml2, json-c, liburing or fuse, and a maximum block size
of 16 KiB on every platform. Multi-threaded compression is on except on windows.

- `build.sh` compiles it for one zig target, straight from the sources configure would pick,
  without autotools. It also builds `fsck.erofs` where it compiles (not windows), for the
  smoke test only; the archive carries `mkfs.erofs` alone.
- `config.h` holds the values configure would find on each target, chosen from the compiler's
  own macros.
- `patches/` are applied to the unpacked release before the build. They make the windows build
  work: the file and tar paths MinGW handles differently, a blocking stdin and `lseek` on a pipe,
  all behind `_WIN32`. Three changes reach every platform, each a no-op where the types are
  already wide enough: pointers cast through `uintptr_t` instead of `unsigned long` (32 bits on
  windows, 64 on the linux and darwin targets), a `REG_NOMATCH` defined only where `regex.h`
  lacks it, and a tar entry's owner and group carried in 32-bit fields instead of `uid_t` and
  `gid_t` (16-bit on MinGW).
- `mingw-compat/` holds headers for the POSIX surface MinGW lacks. `posix_compat.h` is
  force-included into every translation unit on windows.
- `darwin-compat/sys/xattr.h` declares the three macOS extended-attribute calls erofs-utils uses;
  the pinned zig's macOS headers carry no `sys/xattr.h`.
- `smoke.sh` makes images from `testdata/fixture.tar` with five option sets and requires each
  image's sha256 to match the one recorded there, which is the same on every platform: a tar
  fixes every name, mode, owner and time, and `-T0` and `-U` fix the rest. Where `fsck.erofs`
  sits beside it, each image readable without zlib is also extracted and compared with the
  tar's files. A tar read from a pipe must give the same image as the file.
- `testdata/fixture.py` writes `testdata/fixture.tar` byte for byte. CI never runs it; the tar
  is committed.

`mkfs.erofs`'s default block size is the build host's page size, so an image made without `-b`
differs between an x86 and an arm64 host. The smoke test always passes it.

## Licence

erofs-utils is upstream's, under upstream's terms: its library under GPL-2.0-or-later or MIT,
`mkfs.erofs` under MIT, the bundled xxhash under BSD-2-Clause or GPL-2.0-only (`COPYING`,
`LICENSES/GPL-2.0`, `LICENSES/MIT`). lz4's library is under BSD-2-Clause (`LICENSE.lz4`). Each
release archive carries these four files. `patches/` and `mingw-compat/` change and stand in for
erofs-utils' library and are under the same terms, GPL-2.0-or-later or MIT. The corresponding
source is upstream's release tarballs, pinned in `pins.yaml` (url and sha256), with `patches/`
and `mingw-compat/` at the release's tag. This directory's other files are under the
repository's Apache-2.0 licence.
