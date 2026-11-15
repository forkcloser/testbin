#!/usr/bin/env bash
# Flags for the build scripts, which source this file: what makes a binary the
# same bytes wherever and whenever it is built.
#   repro_cflags:  for every compile. No debug information: it names the
#                  source's directory and zig's own.
#   repro_ldflags: for every link. No debug information from zig's runtime
#                  libraries either, no symbol table, and on windows no .pdb
#                  and, where the linker stamps the time of the link, a hash
#                  of what it linked: lld's /Brepro, spelled -Brepro, since
#                  the shell of a windows host rewrites an argument that
#                  begins with a slash into a path under its own root.
# A script sets its zig target, as target, before it sources this.
# shellcheck disable=SC2034 # read by the scripts that source this file
repro_cflags=(-g0)
# shellcheck disable=SC2034
repro_ldflags=(-s)
case "${target:?the zig target, set before this file is sourced}" in
*-windows-*) repro_ldflags+=("-Wl,-Brepro") ;;
esac
