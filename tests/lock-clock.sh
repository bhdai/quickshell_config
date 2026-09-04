#!/usr/bin/env bash

# The clock is the one part of the lock screen whose defects are entirely a matter of what it
# measures: a size, a tracking, a leading, and a width that has to stay put as the digits
# change. Source assertions cannot see any of that, so this renders the real component.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/lock-clock"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/lock" "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the clock and
# what it imports and nothing else. The rest of the lock module pulls in the layer-shell
# surface, which cannot be built with no Wayland session to build it on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/modules/lock/LockClock.qml" "$test_dir/config/modules/lock/LockClock.qml"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
# Time.qml refreshes its clock off SystemSleep, so a config with one and not the other
# throws on load rather than merely losing the refresh.
ln -s "$repo_root/services/SystemSleep.qml" "$test_dir/config/services/SystemSleep.qml"
ln -s "$repo_root/services/SystemSleepParse.js" "$test_dir/config/services/SystemSleepParse.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The clock did not load"
    exit 1
fi

if ! results="$(grep -o 'LOCK_CLOCK .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The clock never finished constructing"
    exit 1
fi

measure() {
    grep -o "LOCK_CLOCK output=$1 .*" <<<"$results"
}

# A binding that throws still leaves the object standing and the walk still logs, so an
# unsupported font property would look like a clock that simply ignored it. The IPC socket is
# not one of ours: quickshell fails to bind it when the runtime path is long.
if grep -v 'quickshell\.ipc' "$test_dir/quickshell.log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$test_dir/quickshell.log"
    echo "The clock loaded with errors"
    exit 1
fi

# The prototype's clamps resolved for each output: 18vw of 1920 exceeds the 300px ceiling,
# 18vw of 1280 does not. The tracking follows the size it is a proportion of, and the date
# clamps the same way. renderType=2 is Text.CurveRendering (QtRendering, NativeRendering,
# CurveRendering) — a distance field cached at one base size and scaled up to display size is
# what makes large type look like a blown-up bitmap.
for expected in "output=1920 size=300 tracking=-27 leading=0.86 gap=26 date=28 render=2" \
    "output=1280 size=230 tracking=-21 leading=0.86 gap=26 date=20 render=2"; do
    if ! grep -qF "$expected" <<<"$results"; then
        echo "$results"
        echo "The clock does not match the prototype: expected $expected"
        exit 1
    fi
done

for output in 1920 1280; do
    result="$(measure "$output")"
    widths="$(sed -n 's/.*widths=\([0-9,]*\).*/\1/p' <<<"$result")"
    if [[ -z "$widths" ]]; then
        echo "$result"
        echo "The walk measured nothing on a $output-wide output"
        exit 1
    fi

    # A centred clock is only as still as its widest and narrowest minute are alike.
    IFS=',' read -r -a measured <<<"$widths"
    for width in "${measured[@]}"; do
        if [[ "$width" -le 0 ]]; then
            echo "$result"
            echo "The time drew nothing on a $output-wide output"
            exit 1
        fi
        if [[ "$width" != "${measured[0]}" ]]; then
            echo "$result"
            echo "The clock changes width as the digits change on a $output-wide output"
            exit 1
        fi
    done
done

echo "The clock matches the prototype on both outputs and holds its width:"
echo "$results"
