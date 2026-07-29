#!/usr/bin/env bash

# The power controls are built only when a lock is raised, so the smoke run never constructs
# them and a QML error in them would first appear behind a locked screen. This builds them
# offscreen and arms one.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/lock-power-controls"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/lock" "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree is assembled from
# the controls' actual dependencies. Handing it the whole repo would drag in the layer-shell
# surfaces, which cannot be built with no Wayland session to build them on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/modules/lock/LockPowerControls.qml" "$test_dir/config/modules/lock/LockPowerControls.qml"
ln -s "$repo_root/modules/lock/LockPower.js" "$test_dir/config/modules/lock/LockPower.js"
ln -s "$repo_root/services/Session.qml" "$test_dir/config/services/Session.qml"
ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The power controls did not load"
    exit 1
fi

if ! result="$(grep -o 'LOCK_POWER_CONTROLS .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The power controls never finished constructing"
    exit 1
fi

read_field() {
    sed -n "s/.*$1=\([^ ]*\).*/\1/p" <<<"$result"
}

width="$(read_field width)"
min_width="$(read_field minWidth)"
if [[ -z "$width" || -z "$min_width" || "$width" -lt "$min_width" ]]; then
    cat "$test_dir/quickshell.log"
    echo "The three controls did not lay out: $result"
    exit 1
fi

# Shutdown arms rather than fires, and a press on restart moves the confirm to restart
# instead of firing the shutdown the user was backing out of.
if [[ "$(read_field armed)" != "poweroff" || "$(read_field moved)" != "reboot" ]]; then
    cat "$test_dir/quickshell.log"
    echo "The confirm did not arm and move as expected: $result"
    exit 1
fi
