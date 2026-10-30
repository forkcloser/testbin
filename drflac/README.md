# drflac

A FLAC decoder on [dr_flac](https://github.com/mackron/dr_libs) (`dr_flac.h`, single header),
from the dr_libs release tag `pins.yaml` pins (`flac-<version>`, sha256), built with the pinned
zig for linux, darwin and windows, amd64 and arm64.

```sh
drflac <input.flac> <output.raw>
```

The output is what `flac -d --force-raw-format --endian=little --sign=signed` writes:
interleaved, signed, little-endian samples at the stream's own bit depth (8, 16, 24 or 32 bits;
another depth is refused). The stream's parameters go to stderr. Exit status 0 on success, 1 on
any error.

- `main.c` is the program around the header, this repository's own.
- `build.sh` compiles it for one zig target.
- `smoke.sh` encodes arbitrary PCM (the `flac` binary's own bytes) with the `flac` build, at 16
  and at 24 bits, decodes it with `drflac`, and requires the original bytes back.

## Licence

dr_flac is upstream's, available as public domain (the Unlicense) or MIT No Attribution, its
choice; each release archive carries dr_libs' `LICENSE` as `LICENSE.dr_libs`. `main.c` and this
directory's other files are under the repository's Apache-2.0 licence, carried as `LICENSE`.
