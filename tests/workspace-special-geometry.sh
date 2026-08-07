#!/usr/bin/env bash

# The special-workspace treatment is supposed to cost zero horizontal pixels: the overlay is
# a sibling drawn over the dot row, not a member of it, so the bar's layout must not move
# when a special is raised. This builds the real widget and measures it both ways.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/workspace-special-geometry"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/bar" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the indicator
# and what it imports and nothing else. The rest of modules/bar pulls in half the services.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/modules/bar/WorkspaceIndicator.qml" "$test_dir/config/modules/bar/WorkspaceIndicator.qml"
ln -s "$repo_root/modules/bar/WorkspaceModel.js" "$test_dir/config/modules/bar/WorkspaceModel.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

log="$test_dir/load.log"

# Timed out rather than left to run: a measurement that throws never reaches Qt.quit(), and
# an offscreen shell with nothing to draw to will happily sit there forever.
if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
    cat "$log"
    echo "The workspace indicator did not load"
    exit 1
fi

# A binding that throws still leaves the object standing and the measurement still logs, so a
# broken one would otherwise look like a widget that simply drew nothing. Hyprland's socket is
# absent by design here — this measures the row at its floor — and its singleton says so on
# every call; that is the fixture's environment, not a defect in the widget.
if grep -v 'quickshell\.ipc\|Hyprland' "$log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$log"
    echo "The workspace indicator loaded with errors"
    exit 1
fi

resting="$(grep -oP '(?<=RESTING )\d+' "$log" | tail -1)"
raised="$(grep -oP '(?<=RAISED )\d+' "$log" | tail -1)"
reveal="$(grep -oP '(?<=REVEAL )[\d.]+' "$log" | tail -1)"

if [[ -z "$resting" || -z "$raised" || -z "$reveal" ]]; then
    cat "$log"
    echo "The workspace indicator never reported its width"
    exit 1
fi

# Five slots at 18 px, four 3 px gaps, 10 px of padding at each outer edge.
if [[ "$resting" != 122 ]]; then
    echo "Expected a resting width of 122, got $resting"
    exit 1
fi

if [[ "$raised" != "$resting" ]]; then
    echo "Raising a special moved the widget's width: $resting -> $raised"
    exit 1
fi

# The blur and the overlay share one driver, so this is also the overlay being fully faded in.
if [[ "$reveal" != 1 ]]; then
    echo "Expected the special reveal to have settled at 1, got $reveal"
    exit 1
fi

echo "The workspace indicator is ${resting}px wide with a special raised and with none"
