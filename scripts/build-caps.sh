#!/usr/bin/env bash
#
# The caps every build runs under, so that it never takes the whole machine
# it runs on.
#
#   BUILD_JOBS     compilers run side by side (scripts/jobs.sh), cargo's and
#                  cabal's jobs (default 4)
#   BUILD_TIMEOUT  wall clock of one tool's build for one platform, as
#                  timeout(1) takes it (default 30m)
#   BUILD_CPUS     processors of hadolint's build container (default 4, or
#                  the host's count where it has fewer)
#   BUILD_MEMORY   its memory, in docker's units (default 8g)
#
# Outside the container nothing caps memory: the job count is what bounds it.
# The .NET builds run one msbuild node (-m:1), below any count given here.
#
#   . build-caps.sh               the variables and functions below
#   build-caps.sh run <command>   the command, capped: every build in the
#                                 .justfile is started this way
#   build-caps.sh container-test <image>
#                                 a container of that image is stopped at
#                                 BUILD_TIMEOUT: run where docker runs
#   build-caps.sh --test          this file's own test

build_jobs="${BUILD_JOBS:-4}"
build_timeout="${BUILD_TIMEOUT:-30m}"
# No more processors than the host has: docker refuses a container more.
build_host_cpus=$( (getconf _NPROCESSORS_ONLN || nproc) 2> /dev/null || echo 4)
build_cpus="${BUILD_CPUS:-$((build_host_cpus < 4 ? build_host_cpus : 4))}"
build_memory="${BUILD_MEMORY:-8g}"
case "${build_jobs}" in
  '' | *[!0-9]* | 0*)
    echo "BUILD_JOBS must be a whole number above 0, not '${build_jobs}'" >&2
    # Sourced or run, either way the build stops here.
    # shellcheck disable=SC2317 # exit is reached when the file is run
    return 2 2> /dev/null || exit 2
    ;;
  *) ;;
esac

# capped <command...>: the command, stopped when it outlasts BUILD_TIMEOUT.
# timeout is the pinned coreutils': it signals the command's whole process
# group, so a make's compilers go with it.
capped() {
  local status=0
  timeout "${build_timeout}" "$@" || status=$?
  [ "${status}" -ne 124 ] || echo "build-caps: stopped after ${build_timeout} (BUILD_TIMEOUT): $*" >&2
  return "${status}"
}

# capped_container <docker run options...> -- <image> <command...>: the
# command in a container of the image, sized, and stopped at BUILD_TIMEOUT
# from inside: a timeout around the docker client stops the client and leaves
# the container building. The image's own timeout runs under a shell, never as
# the container's first process: BusyBox's signals the command from a child
# of it, and a first process is sent no signal it has no handler for. The
# `exit` after it is what keeps the shell: ash execs the last command of a
# -c string in its own place, and timeout would be the first process again.
capped_container() {
  local options=() status=0
  while [ "$1" != -- ]; do
    options+=("$1")
    shift
  done
  shift
  local image=$1
  shift
  # shellcheck disable=SC2016 # the arguments are the container's shell's
  docker run --cpus "${build_cpus}" --memory "${build_memory}" ${options[@]+"${options[@]}"} \
    "${image}" sh -c 'timeout "$0" "$@"; exit $?' "${build_timeout}" "$@" || status=$?
  case "${status}" in
    124 | 143) echo "build-caps: the container was stopped (BUILD_TIMEOUT is ${build_timeout})" >&2 ;;
    *) ;;
  esac
  return "${status}"
}

if [ "${1:-}" = container-test ] && [ "${BASH_SOURCE[0]}" = "$0" ]; then
  # A command that would run a minute, given two seconds: it must be stopped,
  # and soon.
  build_timeout=2s
  started=${SECONDS}
  if said=$(capped_container --rm -- "${2:?image}" sh -c 'sleep 60; echo survived' 2> /dev/null); then
    echo "build-caps: a container past BUILD_TIMEOUT ended with status 0 (${said})" >&2
    exit 1
  fi
  if [ $((SECONDS - started)) -ge 45 ]; then
    echo "build-caps: a container past BUILD_TIMEOUT ran $((SECONDS - started))s" >&2
    exit 1
  fi
  echo "build-caps: a container past BUILD_TIMEOUT is stopped"
  exit 0
fi

if [ "${1:-}" = run ] && [ "${BASH_SOURCE[0]}" = "$0" ]; then
  shift
  # What the build's own tools read the count from: scripts/jobs.sh and
  # hadolint's container take BUILD_JOBS, cargo CARGO_BUILD_JOBS.
  export BUILD_JOBS="${build_jobs}" BUILD_TIMEOUT="${build_timeout}" CARGO_BUILD_JOBS="${build_jobs}"
  capped "$@"
  exit
fi

[ "${1:-}" = '--test' ] && [ "${BASH_SOURCE[0]}" = "$0" ] || return 0 2> /dev/null || exit 0

set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
cases=0
# check <what> <got> <want>
check() {
  cases=$((cases + 1))
  [ "$2" = "$3" ] || { echo "build-caps: $1: got '$2', want '$3'" >&2; exit 1; }
}

# The job count reaches what a build starts, and the container its size.
mkdir "${work}/bin"
printf '#!/bin/sh\necho "docker $*"\n' > "${work}/bin/docker"
chmod 0755 "${work}/bin/docker"
clean=(env -u BUILD_JOBS -u BUILD_TIMEOUT -u BUILD_CPUS -u BUILD_MEMORY -u CARGO_BUILD_JOBS)
# shellcheck disable=SC2016 # the variables are the started command's to expand
seen='echo "$BUILD_JOBS $CARGO_BUILD_JOBS $BUILD_TIMEOUT"'
check 'run, by default' "$("${clean[@]}" scripts/build-caps.sh run sh -c "${seen}")" '4 4 30m'
check 'run, BUILD_JOBS=2' "$("${clean[@]}" BUILD_JOBS=2 BUILD_TIMEOUT=5m scripts/build-caps.sh run sh -c "${seen}")" '2 2 5m'
host_cpus=$( (getconf _NPROCESSORS_ONLN || nproc) 2> /dev/null || echo 4)
check 'the container, by default' "$("${clean[@]}" PATH="${work}/bin:${PATH}" bash -c '. scripts/build-caps.sh && capped_container --rm -- image sh x')" \
  "docker run --cpus $((host_cpus < 4 ? host_cpus : 4)) --memory 8g --rm image sh -c timeout \"\$0\" \"\$@\"; exit \$? 30m sh x"
# shellcheck disable=SC2016 # the text docker was given, not an expansion
check 'the container, sized and timed' "$("${clean[@]}" BUILD_CPUS=2 BUILD_MEMORY=3g BUILD_TIMEOUT=5m PATH="${work}/bin:${PATH}" bash -c '. scripts/build-caps.sh && capped_container --rm -- image sh x')" \
  'docker run --cpus 2 --memory 3g --rm image sh -c timeout "$0" "$@"; exit $? 5m sh x'

# scripts/jobs.sh runs no more commands side by side than the count: each of
# six writes when it starts and when it ends, and no more than two are ever
# between the two.
# shellcheck disable=SC2016 # the arguments are the inner shells' to expand
"${clean[@]}" BUILD_JOBS=2 bash -c '. scripts/jobs.sh; for i in 1 2 3 4 5 6; do spawn sh -c "echo + >> \"$1\"; sleep 0.3; echo - >> \"$1\"" - "$1"; done; join' - "${work}/marks"
most=$(awk '{ if ($1 == "+") n++; else n--; if (n > most) most = n } END { print most }' "${work}/marks")
check 'jobs.sh, BUILD_JOBS=2, six commands' "${most}:$(grep -c . "${work}/marks")" '2:12'

# A job count that is not one stops the build before it starts.
for bad in 0 -1 many 04 ''; do
  status=0
  BUILD_JOBS="${bad}" bash -c '. scripts/build-caps.sh && echo went on' > "${work}/out" 2> /dev/null || status=$?
  if [ "${bad}" = '' ]; then
    # Empty is unset: the default.
    check 'BUILD_JOBS empty' "$(cat "${work}/out")" 'went on'
  else
    check "BUILD_JOBS=${bad} is refused" "${status}:$(cat "${work}/out")" '2:'
  fi
done

# A step that outlasts BUILD_TIMEOUT is stopped, says so, and takes what it
# started with it.
status=0
BUILD_TIMEOUT=1s bash -c '. scripts/build-caps.sh && capped sh -c "sleep 60 & echo \$! > \"$1\"; wait"' - "${work}/pid" 2> "${work}/err" || status=$?
check 'a step past BUILD_TIMEOUT' "${status}" 124
grep -q 'stopped after 1s (BUILD_TIMEOUT)' "${work}/err" || { echo "build-caps: a stopped step does not say so" >&2; exit 1; }
sleep 1
if kill -0 "$(cat "${work}/pid")" 2> /dev/null; then
  kill "$(cat "${work}/pid")"
  echo "build-caps: a stopped step left what it started running" >&2
  exit 1
fi
cases=$((cases + 2))
# A step within it keeps its own status.
status=0
bash -c '. scripts/build-caps.sh && capped sh -c "exit 7"' || status=$?
check 'a failing step keeps its status' "${status}" 7

# Every build the .justfile starts is started capped, and hadolint's
# container through the sized function alone.
if grep -nE '(^|[[:space:]])[a-z]+/build\.sh( |$)|just do build ' .justfile | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v 'scripts/build-caps.sh run ' > "${work}/bare"; then
  cat "${work}/bare" >&2
  echo "build-caps: the .justfile starts a build outside the caps" >&2
  exit 1
fi
if grep -rnE '(^|[^_a-z])docker run' -- */build.sh | grep -vE ':[0-9]+:[[:space:]]*#' > "${work}/bare"; then
  cat "${work}/bare" >&2
  echo "build-caps: a build script runs docker outside the caps" >&2
  exit 1
fi
[ "$(grep -c '^capped_container ' hadolint/build.sh)" -eq 1 ] || { echo "build-caps: hadolint/build.sh does not start its container through capped_container" >&2; exit 1; }
cases=$((cases + 3))
echo "build-caps: ${cases} cases as expected"
