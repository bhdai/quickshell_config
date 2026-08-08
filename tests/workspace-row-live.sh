#!/usr/bin/env bash

# Opening an app on an empty workspace must not disturb the slots already in the row.
#
# The row grows a slot when Hyprland creates a workspace past the five-slot floor and drops it
# again when that workspace empties. Both are length changes to the array the row is built
# from, and a Repeater rebuilds every delegate when an array model's length changes — so every
# dot restarted its 200 ms entry fade and the whole row blinked, twice per app launch.
#
# There is no offline seam for this: the row's length is derived inside the widget from the
# Hyprland singleton, so only a live compositor can change it. This skips where there is none.
#
# The probe window opens with `silent` on the first workspace above the highest in use, so it
# never appears on screen, and it exits on its own.

set -euo pipefail

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "SKIP: no Hyprland instance to drive the row from"
    exit 0
fi

if ! command -v ghostty >/dev/null; then
    echo "SKIP: no ghostty to open on an empty workspace"
    exit 0
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/workspace-row-live"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"

mkdir -p "$test_dir/config/modules/bar"

ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/modules/bar/WorkspaceIndicator.qml" "$test_dir/config/modules/bar/WorkspaceIndicator.qml"
ln -s "$repo_root/modules/bar/WorkspaceModel.js" "$test_dir/config/modules/bar/WorkspaceModel.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

# The ceiling the model clamps to. A row already at it cannot grow, and the probe would prove
# nothing.
max_slots=10
probe_workspace="$(hyprctl workspaces -j | python3 -c '
import json, sys
ids = [w["id"] for w in json.load(sys.stdin) if w["id"] >= 1]
print(max(ids, default=0) + 1)
')"

if (( probe_workspace > max_slots )); then
    echo "SKIP: the row is already at its $max_slots slot ceiling"
    rm -rf "$test_dir"
    exit 0
fi

log="$test_dir/live.log"

QT_QPA_PLATFORM=offscreen timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1 &
qs_pid=$!
trap 'kill "$qs_pid" 2>/dev/null || true; rm -rf "$test_dir"' EXIT

# Past the fixture's 1500 ms settle, so the row is stamped before anything moves.
sleep 3

# Hyprland runs in Lua config mode here, where the `hyprctl dispatch exec ...` form errors.
hyprctl dispatch "hl.dsp.exec_cmd(\"[workspace $probe_workspace silent] ghostty -e sleep 2\")" >/dev/null

# Two seconds for the probe window to live, plus both fades and slack.
sleep 6

kill "$qs_pid" 2>/dev/null || true
wait "$qs_pid" 2>/dev/null || true

stamped="$(grep -oP '(?<=STAMPED )\d+' "$log" | tail -1)"

if [[ -z "$stamped" || "$stamped" == 0 ]]; then
    cat "$log"
    echo "The indicator never reported a row to watch"
    exit 1
fi

if ! grep -q "SAMPLE count=$((stamped + 1))" "$log"; then
    cat "$log"
    echo "The row never grew, so opening on an empty workspace was not actually tested"
    exit 1
fi

# One line per distinct state, so a single rebuilt or re-faded slot anywhere in the run shows
# up here even though the whole thing lasts under a second.
if grep -qP "SAMPLE count=\d+ survivors=(?!$stamped\b)" "$log"; then
    grep 'SAMPLE' "$log"
    echo "Opening an app on an empty workspace rebuilt slots that were already in the row"
    exit 1
fi

if grep -qvE 'faded=0' <(grep 'SAMPLE' "$log"); then
    grep 'SAMPLE' "$log"
    echo "Opening an app on an empty workspace faded slots that were already in the row"
    exit 1
fi

echo "All $stamped slots held identity and opacity while the row grew and shrank"
