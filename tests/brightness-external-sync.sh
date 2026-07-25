#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/brightness-external-sync"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/bin" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

ln -s "$repo_root/services/Brightness.qml" "$test_dir/config/services/Brightness.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"
ln -s "$fixture_dir/brightnessctl" "$test_dir/bin/brightnessctl"
ln -s "$fixture_dir/udevadm" "$test_dir/bin/udevadm"
ln -s /usr/bin/sh "$test_dir/bin/sh"
ln -s /usr/bin/sleep "$test_dir/bin/sleep"
ln -s /usr/bin/cat "$test_dir/bin/cat"

brightness_state="$test_dir/brightness-state"
printf '40\n' >"$brightness_state"

if ! PATH="$test_dir/bin" \
    BRIGHTNESS_TEST_CALLS="$test_dir/brightnessctl-calls" \
    UDEV_TEST_CALLS="$test_dir/udevadm-calls" \
    BRIGHTNESS_STATE="$brightness_state" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    exit 1
fi

if ! grep -q "subsystem-match=backlight" "$test_dir/udevadm-calls" 2>/dev/null; then
    cat "$test_dir/quickshell.log"
    echo "Brightness did not subscribe to udev backlight events"
    exit 1
fi

if ! grep -q "EXTERNAL_SYNCED" "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "Brightness did not pick up a backlight change made outside the shell"
    exit 1
fi
