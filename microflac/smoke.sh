#!/usr/bin/env bash
# What microflac is held to: scripts/decoder-smoke.sh, at the depths it is run at.
#   smoke.sh <directory holding microflac> <directory holding flac>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${here}/../scripts/decoder-smoke.sh" microflac "${1:?directory holding microflac}" "${2:?directory holding flac}" '8 16 24 32'
