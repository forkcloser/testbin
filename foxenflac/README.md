# foxenflac

A FLAC decoder on [libfoxenflac](https://github.com/astoeckel/libfoxenflac) (one C file, no
dynamic allocation in the decoder), from the commit `pins.yaml` pins (sha256), built with the
pinned zig for linux, darwin and windows, amd64 and arm64. libfoxenflac publishes no release, so
the pin is a commit. Renovate moves a commit only as a branch plus a digest, which limen's
`pins.yaml` manager does not capture, so a bump is a hand edit of `version` and `digest.version`.

```sh
foxenflac <input.flac> <output.raw>
```

The output is what `flac -d --force-raw-format --endian=little --sign=signed` writes:
interleaved, signed, little-endian samples at the stream's own bit depth, 8, 16 or 24 bits.
libfoxenflac reads the frame-header depth codes for 8, 12, 16, 20 and 24 bits and no others, so a
32-bit stream does not decode; 12 and 20 bits decode but have no whole-byte raw form and are
refused. libfoxenflac left-justifies every depth in 32 bits; the program shifts each sample back.
The stream's parameters go to stderr. Exit status 0 on success, 1 on any error, a stream that
ends before the frame count its STREAMINFO declares included.

- `main.c` is the program around the library, this repository's own.
- `build.sh` compiles it and `src/foxen-flac.c` for one zig target.
- `smoke.sh` encodes arbitrary PCM (the `flac` binary's own bytes) with the `flac` build, at 16
  and at 24 bits, decodes it with `foxenflac`, and requires the original bytes back.

## Licence

libfoxenflac is upstream's, under the GNU LGPL version 2.1; each release archive carries its
`LICENSE` as `LICENSE.libfoxenflac`. The binary links it statically: the corresponding source is
upstream's tarball of the pinned commit (`pins.yaml`, url and sha256) with this directory at the
release's tag, everything needed to rebuild it against a modified library. `main.c` and this
directory's other files are under the repository's Apache-2.0 licence, carried as `LICENSE`.
