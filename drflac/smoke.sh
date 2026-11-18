#!/usr/bin/env bash
# What drflac is held to: scripts/decoder-smoke.sh, at the depths it is run at.
#   smoke.sh <directory holding drflac> <directory holding flac>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${here}/../scripts/decoder-smoke.sh" drflac "${1:?directory holding drflac}" "${2:?directory holding flac}" '8 16 24 32'
