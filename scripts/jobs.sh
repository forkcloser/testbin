#!/usr/bin/env bash
# Bounded background jobs for the build scripts, which source this file.
#   spawn <command...>: run the command in the background; when BUILD_JOBS of
#                       them are running (build-caps.sh), wait for them first.
#   join:               wait for every command spawned so far.
# A command that fails fails the script that spawned it, at the next spawn
# past the bound or at join: a build script calls join before it uses what
# the commands made.

# shellcheck source=scripts/build-caps.sh
. "$(dirname "${BASH_SOURCE[0]}")/build-caps.sh"
jobs_max=${build_jobs}
jobs_pids=()

join() {
  local pid
  for pid in ${jobs_pids[@]+"${jobs_pids[@]}"}; do
    wait "${pid}"
  done
  jobs_pids=()
}

spawn() {
  if [ "${#jobs_pids[@]}" -ge "${jobs_max}" ]; then
    join
  fi
  "$@" &
  jobs_pids+=("$!")
}
