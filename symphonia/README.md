# symphonia

A FLAC decoder on [Symphonia](https://github.com/pdeljanov/Symphonia) (pure Rust), its FLAC
support alone (`default-features = false`, `features = ["flac"]`), from the crate version
`Cargo.toml` pins and `Cargo.lock` locks by checksum with every crate it links, built with the
Rust toolchain `rust-toolchain.toml` pins, linked through the pinned zig, for linux and windows,
amd64 and arm64, and darwin arm64.

```sh
symphonia <input.flac> <output.raw>
```

The output is what `flac -d --force-raw-format --endian=little --sign=signed` writes:
interleaved, signed, little-endian samples at the stream's own bit depth (8, 16, 24 or 32 bits;
another depth is refused). Symphonia's FLAC decoder left-justifies every depth in 32 bits; the
program shifts each sample back. At 32 bits the samples are Symphonia's as it gives them, and
Symphonia 0.6.1 gets some 32-bit stereo frames wrong, with no error
(https://github.com/pdeljanov/Symphonia/issues/585): the program does not stand in its way. A stream with
no audio frame does not open: Symphonia looks for the first frame as it opens the stream and
reports `unexpected end of file`, where `flac -d` writes an empty output and exits 0. The stream's parameters go to stderr. Exit status 0 on
success, 1 on any error, a frame Symphonia cannot decode included.

- `src/main.rs` is the program around the crates, this repository's own.
- `smoke.sh` runs `scripts/decoder-smoke.sh`, the test every decoder program here is held to: PCM
  encoded by the `flac` build at 8, 16 and 24 bits comes back byte for byte, with the stream's
  parameters on stderr, without arguments the program prints its usage and exits 1, and an input cut short is an
  error. Not at 32
  bits, for the reason above.

## Licence

Symphonia is upstream's, under the Mozilla Public License 2.0; the crates it links are under
their own licences (MIT, Apache-2.0, zlib, as each states). Each release archive carries every
linked crate's licence files under `licences/<crate>-<version>/`, the closure `Cargo.lock`
records (`just _crate-closure testbin-symphonia`). The corresponding source is those crates on
crates.io, `https://static.crates.io/crates/<crate>/<crate>-<version>.crate`, at the checksums
`Cargo.lock` records. `src/main.rs` and this directory's other files are under the
repository's MIT licence, carried as `LICENSE`.
