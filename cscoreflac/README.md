# cscoreflac

A FLAC decoder on [CSCore](https://github.com/filoe/cscore)'s (C#, the decoder the NAudio.Flac
packages derive from), from the release tag `pins.yaml` pins (sha256), published with the .NET
SDK `pins.yaml` pins per platform, self-contained, as one file, for linux, darwin and windows,
amd64 and arm64.

```sh
cscoreflac <input.flac> <output.raw>
```

The output is what `flac -d --force-raw-format --endian=little --sign=signed` writes:
interleaved, signed, little-endian samples at the stream's own bit depth (8, 16 or 24 bits; 12
and 20 bits have no whole-byte raw form and are refused), which is the PCM `FlacFile.Read`
returns. The stream's parameters go to stderr. Exit status 0 on success, 1 on any error.

CSCore's decoder is lenient where the others are strict, and the program makes up for it:
`FlacFile` skips a frame it cannot decode and returns nothing at all for a 32-bit stream, both
without an error, so the program holds the output to the frame count STREAMINFO declares and
refuses a shortfall (a 32-bit stream: `decoded 0 frames, the stream declares …`). One defect it
cannot make up for: on a stream cut off inside a frame, CSCore's unsafe Rice decoder reads past
its buffer (`AccessViolationException` in `FlacPartitionedRice.ReadFlacRiceBlock`), which .NET
does not let a program catch; the process dies, with a nonzero exit status.

- `cscoreflac.csproj` compiles `Program.cs` and `Compat.cs`, this directory's own, with the
  CSCore files the decoder reaches: `CSCore/Codecs/FLAC`, its bit reader and CRCs, the wave
  format types, and `CSCore/Tags/ID3`, which `FlacFile` uses to skip an ID3v2 tag. No upstream
  file is edited, and the rest of CSCore (its Windows audio stack) is not built.
- `Compat.cs` stands in for what those files reach outside that set: two helpers from
  `Extensions.cs` (whose other helpers reach the Windows audio stack), with upstream's
  behaviour; empty namespaces for `using` directives that name nothing used
  (`System.DirectoryServices`, `CSCore.DMO`, `CSCore.MediaFoundation`); and a
  `System.Drawing.Image` that throws, for the ID3 picture frames, which .NET ships for Windows
  alone and the decoder never decodes.
- `build.sh` publishes it for one runtime identifier. `packages.lock.json` pins, by sha512, the
  one package a publish restores (`Microsoft.NET.ILLink.Tasks`), restored in locked mode;
  `just cscoreflac-lock` rewrites it.
- `smoke.sh` encodes arbitrary PCM (the `flac` binary's own bytes) with the `flac` build, at 16
  and at 24 bits, decodes it with `cscoreflac`, and requires the original bytes back.

## Licence

CSCore is upstream's, under the Microsoft Public License (`license.md`, carried in each release
archive as `LICENSE.cscore.md`). The corresponding source is upstream's release tarball, pinned
in `pins.yaml` (url and sha256). `Program.cs` and this directory's other files are under the
repository's Apache-2.0 licence, carried as `LICENSE`; the two helpers in `Compat.cs` reproduce
upstream's (CSCore 1.2.1.2, `Extensions.cs`) and are under its licence.
