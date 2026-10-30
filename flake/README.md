# flake

`CUETools.Flake`, the FLAC encoder of [CUETools](https://github.com/gchudov/cuetools.net)
(Flake, a C# encoder), from the release tag `pins.yaml` pins (`v<version>`, sha256), published
self-contained as one file for linux, darwin and windows, amd64 and arm64, by the .NET SDK
`pins.yaml` pins per platform (Microsoft's archives; each matches Microsoft's published sha512).

```sh
CUETools.Flake [options] <input.wav|input.flac> -o <output.flac>
```

- `build.sh` publishes it for one runtime identifier. Upstream's command targets an end-of-life
  framework (`netcoreapp2.0`); the build sets `TargetFrameworks=net10.0` globally rather than
  editing upstream's projects.
- `Directory.Build.props` is copied into the unpacked tree: NuGet lock files (`locks/`, one per
  project, restored in locked mode), all six runtime identifiers, SourceLink off (the tree sits
  inside this repository's checkout), a deterministic build.
- `standalone.targets` makes upstream's project references private again: CUETools' application
  loads its codecs from a shared plugins directory, so its projects do not copy each other's
  assemblies, and a standalone command must carry them.
- `smoke.sh` encodes arbitrary PCM with `CUETools.Flake`, at 16 and 24 bits, from WAV and from
  FLAC, and requires the original bytes back through `flac`, which must also accept the stream.

What the lock files pin: every NuGet package a project references, by sha512 (Newtonsoft.Json).
The runtime packs a self-contained publish downloads are not references, so NuGet records them in
no lock file: their versions are the pinned SDK's, and NuGet verifies their signatures.

## Licence

The sources and the binaries built from them are upstream's, under upstream's licences: CUETools
and the `CUETools.Flake` command under the GNU GPL version 2 or later (`License.txt`), the
CUETools.Codecs library under the GNU LGPL version 2.1 or later (`License.CUETools.Codecs.txt`),
the Flake codec library under the GNU LGPL version 2.1 (`COPYING`, the licence's text),
Newtonsoft.Json under the MIT licence (`LICENSE.Newtonsoft.Json.md`). Each release archive
carries the four. The corresponding source is upstream's release tarball, pinned in `pins.yaml`
(url and sha256): `https://github.com/gchudov/cuetools.net/archive/refs/tags/v<version>.tar.gz`.
This directory's own files are under the repository's Apache-2.0 licence.
