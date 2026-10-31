# microflac

A FLAC decoder on [microFLAC](https://github.com/esphome-libs/micro-flac) (C++, ESPHome's FLAC
decoder, its decoder based on Project Nayuki's Simple FLAC Implementation), from the release tag
`pins.yaml` pins (`v<version>`, sha256), built with the pinned zig for linux, darwin and
windows, amd64 and arm64. The build leaves out microFLAC's Ogg demuxer (`MICRO_FLAC_DISABLE_OGG`):
it is a git submodule the release tarball does not carry, and native FLAC is what the tool
decodes. The encoder's sources are not built.

```sh
microflac <input.flac> <output.raw>
```

The output is what `flac -d --force-raw-format --endian=little --sign=signed` writes:
interleaved, signed, little-endian samples at the stream's own bit depth (8, 16, 24 or 32 bits;
another depth is refused), which is microFLAC's own byte-packed output on every host. Frame CRCs
are checked (microFLAC's default). The stream's parameters go to stderr. Exit status 0 on
success, 1 on any error, a stream that ends before the frame count its STREAMINFO declares
included.

- `main.cpp` is the program around the library, this repository's own.
- `build.sh` compiles it and microFLAC's decoder sources (`cmake/sources.cmake`'s) for one zig
  target.
- `smoke.sh` encodes arbitrary PCM (the `flac` binary's own bytes) with the `flac` build, at 16,
  24 and 32 bits, decodes it with `microflac`, and requires the original bytes back.

## Licence

microFLAC is upstream's, under the Apache License 2.0; each release archive carries its `LICENSE`
as `LICENSE.microflac`. The corresponding source is upstream's release tarball, pinned in
`pins.yaml` (url and sha256). `main.cpp` and this directory's other files are under the
repository's Apache-2.0 licence, carried as `LICENSE`.
