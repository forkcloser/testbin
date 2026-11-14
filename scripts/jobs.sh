#!/usr/bin/env bash
# Bounded background jobs for the build scripts, which source this file.
#   spawn <command...>: run the command in the background; when as many are
#                       running as the host has processors, wait for them first.
#   join:               wait for every command spawned so far.
# A command that fails fails the script that spawned it, at the next spawn
# past the bound or at join: a build script calls join before it uses what
# the commands made.

jobs_max=$( (getconf _NPROCESSORS_ONLN || nproc) 2> /dev/null || echo 2)
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
