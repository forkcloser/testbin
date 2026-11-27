#!/bin/sh
# The half of hadolint/build.sh that runs inside the alpine image: the
# packages upstream's release installs, the pinned GHC and cabal-install from
# the tarballs mounted at /in, then upstream's own two cabal commands, with
# the dependencies this repository froze.
set -eu
export LC_ALL=C
commit=${HADOLINT_COMMIT:?the pinned hadolint commit}
url=${HADOLINT_URL:?the pinned hadolint source url}

# The packages upstream's release installs, and jq for the plan. The image is
# pinned by digest and these are installed into it at whatever alpine serves:
# so every package the container then holds is compared with
# hadolint/apk.lock, the linker and the assembler as much as the libraries,
# and the build stops when alpine has moved one.
apk add --cache-dir /kept/apk \
  curl gcc g++ ncurses-dev libffi-dev make xz gzip tar perl git jq \
  binutils-gold zlib zlib-dev zlib-static gmp gmp-dev gmp-static \
  ncurses-static libc-dev musl-dev > /dev/null
apk info -v 2> /dev/null | sort > /apk.installed
# grep finds nothing in a lock that names no package yet, and says so by its
# exit status.
grep -v '^#' /in/recipe/apk.lock > /apk.locked || true
cmp -s /apk.locked /apk.installed || {
  echo "hadolint: the container does not hold the packages hadolint/apk.lock names (-: the lock, +: installed):" >&2
  diff /apk.locked /apk.installed >&2 || true
  echo "hadolint: when alpine has moved a package, read hadolint/apk-linked: one of those is in the binary, with its licence and its source" >&2
  exit 1
}

mkdir -p /build/ghc /build/src /build/cabal
tar -xJf /in/ghc.tar.xz -C /build/ghc --strip-components=1
(cd /build/ghc && ./configure --prefix=/opt/ghc > /build/ghc-configure.log 2>&1 && make install > /build/ghc-install.log 2>&1) ||
  { tail -n 30 /build/ghc-configure.log /build/ghc-install.log >&2; exit 1; }
tar -xJf /in/cabal.tar.xz -C /usr/local/bin
export PATH="/opt/ghc/bin:${PATH}"

# GHC links hadolint's libraries in the order it met them, which is the order
# of each package database's cache, which is the order ghc-pkg was handed the
# database's directory in: the file system's, another on another machine
# (ext4 hashes names with a seed of its own), and for cabal's store the order
# a parallel build finished in. Two libraries neither of which needs the
# other then change places in the binary. So each database's cache is written
# again from a directory that lists its files in the order of their names.
# No file system promises that order: one that lists files as they were made
# (tmpfs since Linux 6.6) or the other way round (before) gives it when the
# files are made in the right order, so both are tried and the listing is
# read back; where neither gives it the build stops.
ordered_db() {
  db=$1
  [ -d "${db}" ] || { echo "hadolint: no package database at ${db}" >&2; exit 1; }
  scratch=/tmp
  [ ! -d /dev/shm ] || scratch=/dev/shm
  ordered="${scratch}/ordered-db"
  find "${db}" -maxdepth 1 -name '*.conf' | sort > /build/db.confs
  [ -s /build/db.confs ] || { echo "hadolint: no package in ${db}" >&2; exit 1; }
  sed 's|.*/||' /build/db.confs > /build/db.names
  for made in first-first last-first; do
    rm -rf "${ordered}"
    mkdir "${ordered}"
    if [ "${made}" = first-first ]; then cat /build/db.confs; else sort -r /build/db.confs; fi |
      while read -r conf; do
        cp "${conf}" "${ordered}/"
      done
    find "${ordered}" -name '*.conf' | sed 's|.*/||' > /build/db.listed
    ! cmp -s /build/db.names /build/db.listed || break
    rm -rf "${ordered}"
  done
  [ -d "${ordered}" ] || {
    echo "hadolint: ${scratch} lists files neither in the order they are made nor in the reverse: no package database can be given one order here, and the binary would not be the one another machine builds" >&2
    exit 1
  }
  ghc-pkg recache --package-db "${ordered}" > /dev/null
  cp "${ordered}/package.cache" "${db}/package.cache"
  rm -rf "${ordered}"
  sha256sum "${db}/package.cache" | cut -c1-16
}
global_db=$(ordered_db "$(ghc --print-global-package-db)")
echo "toolchain: $(ghc --numeric-version), $(cabal --numeric-version)"

cp -R /in/src/. /build/src/
# Upstream commits no freeze file and resolves its dependencies on the day of
# the build. This repository's own pins every package to one version, at the
# state of Hackage it names; cabal checks each against that index.
cp /in/recipe/cabal.project.local /build/src/cabal.project.local
cp /in/recipe/cabal.project.freeze /build/src/cabal.project.freeze
cd /build/src
export CABAL_DIR=/build/cabal
cabal update > /build/cabal-update.log 2>&1 || { cat /build/cabal-update.log >&2; exit 1; }
# The freeze file is the whole plan: resolved again, nothing in it moves.
cp cabal.project.freeze /build/freeze.committed
cabal freeze > /dev/null
cmp -s cabal.project.freeze /build/freeze.committed || {
  echo "hadolint: cabal resolves another plan than hadolint/cabal.project.freeze holds:" >&2
  diff /build/freeze.committed cabal.project.freeze >&2 || true
  exit 1
}

# The dependencies, in two steps. cabal-install builds a package of build
# type Simple inside its own process, the copy into its store included, and
# opens no file close-on-exec: whatever it starts while a file is open for
# writing inherits the descriptor and holds it for as long as it runs. With
# several jobs, a compiler started for one package while cabal writes the
# executable of another holds that executable open for writing, and the
# kernel refuses to run a file somebody may write to (ETXTBSY, "Text file
# busy"): the build then fails at the first package that runs the tool. So
# the executables the plan runs during the build (alex is one) are built
# first, one job at a time, by a cabal that has exited before the rest is
# built in parallel; that second cabal finds them in its store and writes
# none of them.
deps() {
  cabal build "$@" --disable-shared --ghc-options='-split-sections -optl-static -fPIC'
}
deps --only-dependencies --dry-run > /build/deps.log 2>&1 || { tail -n 60 /build/deps.log >&2; exit 1; }
# shellcheck disable=SC2016 # jq's variables, not the shell's
jq -r '
  ."install-plan" as $plan
  | [$plan[] | (."exe-depends" // []), ((.components // {})[] | ."exe-depends" // [])] | flatten | unique as $run
  | $plan[] | select(.type == "configured" and (.id as $id | $run | index($id) != null))
  | ."pkg-name" as $name
  | if ."component-name" then [[."component-name", ."bin-file"]]
    else [(.components // {}) | to_entries[] | select(.key | startswith("exe:")) | [.key, .value."bin-file"]] end
  | .[] | [$name, .[0], (.[1] // "")] | @tsv' \
  dist-newstyle/cache/plan.json > /build/tools.plan
sort -u /build/tools.plan > /build/tools
# The plan this repository froze runs alex: a list with nothing in it is a
# plan that was not read, and the checks below would pass on nothing. A kept
# store that already holds the tools changes nothing here: the plan is written
# before cabal looks at its store, and building what is built does nothing.
[ -s /build/tools ] || { echo "hadolint: the plan names no executable to build first" >&2; exit 1; }
# Fully qualified: cabal reads the shorter "alex:exe:alex" two ways and stops.
tool_targets=$(awk -F '\t' '{ printf ":pkg:%s:%s ", $1, $2 }' /build/tools)
awk -F '\t' '$3 == "" { print "hadolint: the plan names no file for " $1 " " $2 > "/dev/stderr"; bad = 1 } END { exit bad }' /build/tools
cut -f 3 /build/tools > /build/tools.files
started=$(date +%s)
# shellcheck disable=SC2086 # one target a word
deps -j1 ${tool_targets} > /build/tools.log 2>&1 || { tail -n 60 /build/tools.log >&2; exit 1; }
# Each of them as the store now holds it: its inode, its times and its size.
tools_state() {
  while read -r file; do
    [ -x "${file}" ] || { echo "hadolint: ${file}, an executable the build runs, is not in the store" >&2; return 1; }
    stat -c '%i %Y %Z %s %n' "${file}"
  done < /build/tools.files
}
tools_state > /build/tools.before
# No process has one of them open for writing when the parallel build starts.
# shellcheck disable=SC2012 # the listing's arrows are what is read
ls -l /proc/[0-9]*/fd 2> /dev/null |
  awk '/^\/proc\//{ split($0, a, "/"); pid = a[3] } / -> \//{ print pid, $(NF-2), $NF }' |
  while read -r pid fd target; do
    grep -q -x -F -- "${target}" /build/tools.files || continue
    flags=$(sed -n 's/^flags:[[:space:]]*//p' "/proc/${pid}/fdinfo/${fd}" 2> /dev/null) || continue
    case "${flags}" in *[1256]) echo "${pid} $(tr '\0' ' ' < "/proc/${pid}/cmdline" 2> /dev/null | cut -c1-120): ${target}" ;; esac
  done > /build/tools.held
[ ! -s /build/tools.held ] || {
  echo "hadolint: a process holds an executable the build runs open for writing:" >&2
  cat /build/tools.held >&2
  exit 1
}
between=$(date +%s)
deps --only-dependencies > /build/deps.log 2>&1 || { tail -n 60 /build/deps.log >&2; exit 1; }
store_db=$(find /build/cabal/store -mindepth 2 -maxdepth 2 -name package.db)
[ "$(echo "${store_db}" | wc -l)" -eq 1 ] || { echo "hadolint: not one package database in cabal's store: ${store_db}" >&2; exit 1; }
# The same on every machine that builds this commit, or the binary is not.
store_db=$(ordered_db "${store_db}")
echo "package databases: GHC's ${global_db}, cabal's store's ${store_db}"
echo "dependencies: $((between - started)) s for ${tool_targets}one job at a time, $(($(date +%s) - between)) s for the rest"
# The link writes its map: what the linker took, read below.
cabal build --enable-executable-static --disable-executable-dynamic --disable-shared \
  --ghc-options='-split-sections -optl-static -optl-pthread -fPIC -optl-Wl,-Map=/build/link.map' exe:hadolint > /build/build.log 2>&1 || { tail -n 60 /build/build.log >&2; exit 1; }
cp "$(cabal list-bin hadolint)" /out/hadolint
# The parallel build and the link wrote none of the executables built first:
# with none open for writing when it started, none was ever open for writing
# while it ran one.
tools_state > /build/tools.after
cmp -s /build/tools.before /build/tools.after || {
  echo "hadolint: an executable built first was written again by the parallel build (-: before, +: after):" >&2
  diff /build/tools.before /build/tools.after >&2 || true
  exit 1
}
strip /out/hadolint
chmod 0755 /out/hadolint

# Which alpine packages are in the binary, measured: every archive and object
# the link map names, asked of apk, is one of hadolint/apk-linked's packages,
# and each of those is there. What GHC and cabal built is not apk's.
[ -s /build/link.map ] || { echo "hadolint: the link wrote no map" >&2; exit 1; }
grep -o '/[^ ()]*\.[ao]' /build/link.map | sort -u | while read -r path; do
  real=$(readlink -f "${path}" 2> /dev/null || true)
  [ -n "${real}" ] || continue
  apk info --who-owns "${real}" 2> /dev/null | sed -n 's/^.* is owned by //p'
done | sort -u > /build/linked.measured
sed -n 's/^\([a-z][^ ]*\) \(.*\)$/\1-\2/p' /in/recipe/apk-linked | sort > /build/linked.named
[ -s /build/linked.measured ] || { echo "hadolint: the link map names nothing of alpine's" >&2; exit 1; }
cmp -s /build/linked.named /build/linked.measured || {
  echo "hadolint: the alpine packages in the binary are not those hadolint/apk-linked names (-: named, +: in the link map):" >&2
  diff /build/linked.named /build/linked.measured >&2 || true
  exit 1
}

# NOTICES, COPYING.LESSER and SOURCE are every platform's (notices.sh); what
# is this one's is written here first: musl and GCC's runtime from alpine,
# the libffi GHC carries, and the alpine packages' own sources.
ghc_version=$(ghc --numeric-version)
version_of() { sed -n "s/^$1 \(.*\)-r[0-9]*\$/\1/p" /in/recipe/apk-linked; }
musl=$(version_of musl-dev)
gmp=$(version_of gmp-static)
gcc=$(version_of gcc)
{
  echo "hadolint is statically linked: everything below is in the binary beside"
  echo "this file. hadolint's own licence is LICENSE, the GNU GPL version 3."
} > /build/notices.head
{
  echo "musl ${musl}:LICENSE-musl-${musl}"
  echo "GCC ${gcc}, its runtime, under the GNU GPL version 3 (LICENSE) with this exception:LICENSE-gcc-runtime-${gcc}"
  echo "libffi, the copy GHC ${ghc_version} carries and links into its runtime:LICENSE-libffi-ghc-${ghc_version}"
} > /build/notices.parts
{
  echo "The corresponding source of this hadolint binary. It is statically linked:"
  echo "every component below is in it. Built by forkcloser/testbin, whose recipe"
  echo "(hadolint/, at the tag of the release this archive belongs to) builds it"
  echo "again from these sources, to the same bytes for as long as Alpine serves"
  echo "the packages hadolint/apk.lock names, and against another GMP by moving"
  echo "that file's gmp lines and hadolint/apk-linked's:"
  echo "  https://github.com/forkcloser/testbin"
} > /build/source.head
echo "  and the libffi its runtime links (libffi-tarballs/ in the same archive)," > /build/source.ghc
{
  echo "From Alpine Linux, each package at its version and the commit of"
  echo "https://gitlab.alpinelinux.org/alpine/aports that built it, whose APKBUILD"
  echo "names the upstream source and the patches applied:"
  sed -n 's/^\([a-z][^ ]*\) .*$/\1/p' /in/recipe/apk-linked | while read -r package; do
    awk -v want="${package}" '
      /^P:/ { name = substr($0, 3) } /^V:/ { version = substr($0, 3) } /^o:/ { origin = substr($0, 3) } /^c:/ { commit = substr($0, 3) }
      /^$/ { if (name == want) { printf "  %s %s: main/%s at %s\n", name, version, origin, commit; found = 1 } name = "" }
      END { if (!found) exit 1 }' /lib/apk/db/installed || { echo "hadolint: ${package} is not installed" >&2; exit 1; }
  done
} > /build/source.tail
NOTICES_PLAN=dist-newstyle/cache/plan.json NOTICES_RECIPE=/in/recipe NOTICES_OUT=/out NOTICES_WORK=/build \
  NOTICES_GHC_DOC=/opt/ghc/share/doc NOTICES_GMP="${gmp}" \
  NOTICES_ALSO="of alpine's: $(tr '\n' ' ' < /build/linked.measured)" \
  NOTICES_HEAD=/build/notices.head NOTICES_PARTS=/build/notices.parts NOTICES_SOURCE_HEAD=/build/source.head \
  NOTICES_GHC_ALSO=/build/source.ghc NOTICES_SOURCE_TAIL=/build/source.tail \
  HADOLINT_COMMIT="${commit}" HADOLINT_URL="${url}" sh /in/recipe/notices.sh

# The kept directory is written here as root and read outside as whoever runs
# the container.
chmod -R a+rX /kept/apk /build/cabal
