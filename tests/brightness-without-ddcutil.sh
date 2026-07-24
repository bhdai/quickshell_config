#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/brightness-without-ddcutil"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/bin" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

ln -s "$repo_root/services/Brightness.qml" "$test_dir/config/services/Brightness.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"
ln -s "$fixture_dir/brightnessctl" "$test_dir/bin/brightnessctl"
ln -s /usr/bin/sh "$test_dir/bin/sh"

brightness_calls="$test_dir/brightnessctl-calls"

if ! PATH="$test_dir/bin" \
    BRIGHTNESS_TEST_CALLS="$brightness_calls" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    exit 1
fi

if grep -q 'Command: QList("ddcutil"' "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "Brightness attempted to execute a missing ddcutil binary"
    exit 1
fi

if ! grep -q "BRIGHTNESS_READY" "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "Brightness did not initialize through brightnessctl"
    exit 1
fi

if ! grep -q -- "--class backlight s 60 --quiet" "$brightness_calls"; then
    cat "$test_dir/quickshell.log"
    echo "Brightness did not adjust through brightnessctl"
    exit 1
fi

mkdir -p "$test_dir/runtime-with-ddcutil"
chmod 700 "$test_dir/runtime-with-ddcutil"
ln -s "$fixture_dir/ddcutil" "$test_dir/bin/ddcutil"

ddc_calls="$test_dir/ddcutil-calls"

if ! PATH="$test_dir/bin" \
    BRIGHTNESS_TEST_CALLS="$brightness_calls" \
    DDC_TEST_CALLS="$ddc_calls" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime-with-ddcutil" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell-with-ddcutil.log" 2>&1; then
    cat "$test_dir/quickshell-with-ddcutil.log"
    exit 1
fi

if ! grep -q "detect --brief" "$ddc_calls"; then
    cat "$test_dir/quickshell-with-ddcutil.log"
    echo "Brightness did not detect monitors when ddcutil was available"
    exit 1
fi
