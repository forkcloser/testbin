#!/usr/bin/env bash
# What claxon is held to: scripts/decoder-smoke.sh, at the depths it is run at.
#   smoke.sh <directory holding claxon> <directory holding flac>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${here}/../scripts/decoder-smoke.sh" claxon "${1:?directory holding claxon}" "${2:?directory holding flac}" '8 16 24'
