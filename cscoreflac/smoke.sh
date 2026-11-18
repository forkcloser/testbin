#!/usr/bin/env bash
# What cscoreflac is held to: scripts/decoder-smoke.sh, at the depths it is run at.
#   smoke.sh <directory holding cscoreflac> <directory holding flac>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${here}/../scripts/decoder-smoke.sh" cscoreflac "${1:?directory holding cscoreflac}" "${2:?directory holding flac}" '8 16 24'
