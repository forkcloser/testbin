# graphviz

`dot`, from [Graphviz](https://gitlab.com/graphviz/graphviz)'s release `pins.yaml` pins, with
[expat](https://github.com/libexpat/libexpat) for HTML-like labels, built with the pinned zig
for linux and windows, amd64 and arm64, and darwin arm64. The sources are compiled as they ship,
unpatched, with the layout engines and the core renderers inside the program, as upstream's
`dot_static`: no plugin is loaded at run time.

- `build.sh` compiles it for one zig target, without running configure.
- `config.h` and `expat_config.h` stand in for what configure would write, the same on every
  host.
- `notices.sh` writes the notices of the two pieces of Graphviz under terms of their own.
- `smoke.sh` requires `dot -V` to name the pinned release, `-Tcanon` to write a fixed graph back
  byte for byte, and the dot engine to lay it out.

## What this build leaves out

The build takes no library but expat. A dot from a distribution is usually built with more, and
answers differently in the cases below. Each was observed on this build's `dot` 16.1.1.

- **No triangulation library (GTS).** `sfdp` is among the engines and cannot succeed: on every
  graph, a single node included, it prints `Error: remove_overlap: Graphviz not built with
  triangulation library`, writes its layout and exits 1. `overlap=prism` is ignored with a
  warning (`Overlap value "prism" unsupported - ignored`). `overlap=false` is accepted with no
  message, and removes overlaps by another method than the Prism one a build with the library
  uses, so `neato` and `fdp` can place nodes elsewhere than a standard dot does.
- **No IPSEPCOLA.** `neato` with `mode=ipsep` warns (`Illegal value ipsep for attribute
  "mode"`), ignores the attribute and lays out in its default mode.
- **No pango, no cairo.** Text is measured by Graphviz's own estimate, so a node with a label is
  not the size a build with pango gives it, and every coordinate of a laid-out graph with text
  can differ from such a build's. None of the cairo formats (`pdf`, `png` and the others) is
  written.
- **No gd.** `gif`, `jpeg`, `gd`, `gd2`, `wbmp` and `vrml` are not written.
- **No zlib.** `svgz` is not written.
- **No ltdl, and no plugin beyond the built-in ones** (core, the dot and neato layouts, vt):
  `kitty`, `webp` and every other plugin's format are not written.

A format that is not written is refused: `Format: "svgz" not recognized. Use one of: …`, exit 1.
The formats written are those `dot -T?` lists: `canon`, `cmap`, `cmapx`, `cmapx_np`, `dot`,
`dot_json`, `eps`, `fig`, `gv`, `imap`, `imap_np`, `ismap`, `json`, `json0`, `pic`, `plain`,
`plain-ext`, `pov`, `ps`, `ps2`, `svg`, `svg_inline`, `tk`, the `vt` forms, `xdot`, `xdot1.2`,
`xdot1.4` and `xdot_json`. The engines are `circo`, `dot`, `fdp`, `neato`, `nop`, `nop1`,
`nop2`, `osage`, `patchwork`, `sfdp` and `twopi`.

On windows the C library has no `drand48`, and Graphviz falls back to `rand`: a seeded layout
(`neato`, `fdp`) differs there from the other platforms.
