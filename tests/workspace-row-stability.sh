#!/usr/bin/env bash

# The dot row must survive a change to the data behind it. It is a Repeater over the array
# `workspaceModel()` returns, and every model input — a window opening on a workspace, the
# active workspace moving, a special being raised — re-runs that binding. If a re-run rebuilds
# the delegates, each restarts at `opacity: 0` and fades in, and the row blinks.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/workspace-row-stability"
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

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
    cat "$log"
    echo "The workspace indicator did not load"
    exit 1
fi

# Hyprland's socket is absent by design here — the row rests at its five-slot floor — and its
# singleton says so on every call; that is the fixture's environment, not a defect.
if grep -v 'quickshell\.ipc\|Hyprland' "$log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$log"
    echo "The workspace indicator loaded with errors"
    exit 1
fi

settled="$(grep -oP '(?<=SETTLED )\d+' "$log" | tail -1)"
after="$(grep -oP '(?<=AFTER )\d+' "$log" | tail -1)"
survivors="$(grep -oP '(?<=SURVIVORS )\d+' "$log" | tail -1)"
opacities="$(grep -oP '(?<=AFTER_OPACITY ).*' "$log" | tail -1)"

if [[ -z "$settled" || -z "$after" || -z "$survivors" || -z "$opacities" ]]; then
    cat "$log"
    echo "The fixture never reported the row"
    exit 1
fi

if [[ "$settled" != 5 || "$after" != 5 ]]; then
    echo "Expected five slots throughout, got $settled then $after"
    exit 1
fi

if [[ "$survivors" != "$after" ]]; then
    echo "The row was rebuilt: $survivors of $after slots survived a model change"
    exit 1
fi

if [[ "$opacities" == *0.* ]]; then
    echo "The row faded back in after a model change: opacities $opacities"
    exit 1
fi

if ! grep -q 'MODEL_SPECIAL special:probe' "$log"; then
    cat "$log"
    echo "The model change never reached the row, so its stability was not tested"
    exit 1
fi

echo "All $after slots survived a model change, opacities $opacities"
