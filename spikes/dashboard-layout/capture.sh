#!/usr/bin/env bash
#
# Renders every variant to a PNG with no display attached, and prints the measurements.
#
#   ./capture.sh [outdir]        # default ./shots
#
# This is what makes the spike reviewable by someone — or something — that cannot see the
# screen. `QT_QPA_PLATFORM=offscreen` still gives Qt Quick a real scene graph, so
# grabToImage returns the same pixels a visible window would.

set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
out="$(cd -- "$(dirname -- "${1:-$here/shots}")" && pwd)/$(basename -- "${1:-shots}")"
stage="$("$here/stage.sh")"

mkdir -p "$out"
rm -f "$out"/*.png

log="$stage/capture.log"

# The spike quits itself once the last shot is written; the timeout is only a backstop for
# a run that never gets there.
DASH_CAPTURE_DIR="$out" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$stage/runtime" \
    timeout 90 qs --no-color -p "$stage/config" >"$log" 2>&1 || true

grep -E '^\s*(DEBUG qml: )?(METRICS|SHOT)' "$log" | sed -E 's/^\s*DEBUG qml: //' || true

if grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign|is not a type' "$log"; then
    echo
    echo "--- the spike loaded with errors ---"
    grep -E 'ERROR|TypeError|ReferenceError|Unable to assign|is not a type' "$log"
    exit 1
fi

if [[ -z "$(ls -A "$out")" ]]; then
    cat "$log"
    echo "no shots were written"
    exit 1
fi

echo
echo "shots in $out:"
ls -1 "$out"
