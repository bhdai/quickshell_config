#!/usr/bin/env bash
#
# Opens the spike as an ordinary window on the running session. See README.md for keys.
#
# Safe against the live shell in a way `qs -p` on the repo root is not: this stages only
# the spike plus modules/common, so it raises one FloatingWindow and no bar, no lock, and
# no layer surface.

set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
stage="$("$here/stage.sh")"

exec qs --no-color -p "$stage/config"
