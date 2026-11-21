#!/usr/bin/env bash
# What foxenflac is held to: scripts/decoder-smoke.sh, at the depths it is run at.
#   smoke.sh <directory holding foxenflac> <directory holding flac>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${here}/../scripts/decoder-smoke.sh" foxenflac "${1:?directory holding foxenflac}" "${2:?directory holding flac}" '8 16 24'
