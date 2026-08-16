#!/usr/bin/env bash

# The timestamp and clock rules are unit-tested; this checks the indicator is wired to the
# recorder's real state file -- that it opens when the file appears, counts from the name
# rather than from when the shell started, and gives its width back when the file goes.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/recording-indicator"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

ln -s "$repo_root/modules" "$test_dir/config/modules"
ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/services/screen_recording.js" "$test_dir/config/services/screen_recording.js"
ln -s "$repo_root/services/ScreenRecording.qml" "$test_dir/config/services/ScreenRecording.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

# A recording that started 65 seconds ago, named exactly as capture-screenrecording names
# them. The clock has to read this back off the filename; anything counting from when the
# shell noticed the file would report a couple of seconds instead.
started="$(date -d '65 seconds ago' +'%Y-%m-%d_%H-%M-%S')"
echo "$HOME/Videos/screenrecording-$started.mp4" >"$test_dir/runtime/screenrecording-filename"

if ! DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_dir/no-system-bus" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The recording indicator did not build"
    exit 1
fi

if ! results="$(grep -o 'RECORDING .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The recording indicator never reported a state"
    exit 1
fi

field_of() {
    sed -n "s/.*name=$1 .*$2=\([^ ]*\).*/\1/p" <<<"$results"
}

# A ligature the font does not carry renders as the literal string, which is many times
# wider than the one em a glyph occupies.
glyph_width="$(field_of recording glyph)"
if [[ -z "$glyph_width" || "$glyph_width" -gt 20 ]]; then
    echo "screen_record did not resolve to a glyph (width $glyph_width): $results"
    exit 1
fi

if [[ "$(field_of recording visible)" != "true" ]]; then
    echo "a running recording left the indicator out of the row: $results"
    exit 1
fi

width="$(field_of recording width)"
if [[ "$width" -lt 30 ]]; then
    echo "the recording pill did not open to a legible width ($width): $results"
    exit 1
fi

if [[ "$(field_of recording hasClock)" != "true" ]]; then
    echo "the recorder's filename carried a timestamp but no clock was shown: $results"
    exit 1
fi

# 65 seconds ago, give or take the second the fixture takes to get going.
clock="$(field_of recording clock)"
if [[ "$clock" != "1:05" && "$clock" != "1:06" ]]; then
    echo "the clock read $clock for a recording started 65s ago: $results"
    exit 1
fi

# The regression that matters: a pill that never closes sits in the bar all session.
if [[ "$(field_of stopped width)" != "0" ]]; then
    echo "the pill kept its width after the recording stopped: $results"
    exit 1
fi

if [[ "$(field_of stopped visible)" != "false" ]]; then
    echo "the pill stayed in the row after the recording stopped: $results"
    exit 1
fi
