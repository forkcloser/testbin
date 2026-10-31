# claxon

A FLAC decoder on [Claxon](https://github.com/ruuda/claxon) (pure Rust), from the crate version
`Cargo.toml` pins and `Cargo.lock` locks by checksum, built with the Rust toolchain
`rust-toolchain.toml` pins, linked through the pinned zig, for linux, darwin and windows, amd64
and arm64.

```sh
claxon <input.flac> <output.raw>
```

The output is what `flac -d --force-raw-format --endian=little --sign=signed` writes:
interleaved, signed, little-endian samples at the stream's own bit depth (8, 16, 24 or 32 bits;
another depth is refused). The stream's parameters go to stderr. Exit status 0 on success, 1 on
any error. Claxon predates RFC 9639: it reads frame-header depth codes for 8, 12, 16, 20 and 24
bits, refuses the 32-bit code as reserved, and refuses a header that leaves the depth to the
stream info, so a 32-bit stream, or one of a depth without a code of its own, does not decode.

- `src/main.rs` is the program around the crate, this repository's own.
- `smoke.sh` encodes arbitrary PCM (the `flac` binary's own bytes) with the `flac` build, at 16
  and at 24 bits, decodes it with `claxon`, and requires the original bytes back.

## Licence

Claxon is upstream's, under the Apache License 2.0; each release archive carries its `license`
file as `LICENSE.claxon`. The corresponding source is the crate on crates.io,
`https://static.crates.io/crates/claxon/claxon-<version>.crate`, the checksum `Cargo.lock`
records. `src/main.rs` and this directory's other files are under the repository's Apache-2.0
licence, carried as `LICENSE`.
