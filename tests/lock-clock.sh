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
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The clock did not load"
    exit 1
fi

if ! result="$(grep -o 'LOCK_CLOCK .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The clock never finished constructing"
    exit 1
fi

# A binding that throws still leaves the object standing and the walk still logs, so an
# unsupported font property would look like a clock that simply ignored it. The IPC socket is
# not one of ours: quickshell fails to bind it when the runtime path is long.
if grep -v 'quickshell\.ipc' "$test_dir/quickshell.log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$test_dir/quickshell.log"
    echo "The clock loaded with errors"
    exit 1
fi

# The prototype's metrics, resolved for a 1920-wide output: 300px, -.09em, .86, 26px, 28px.
for expected in "size=300" "tracking=-27" "leading=0.86" "gap=26" "date=28"; do
    if [[ "$result" != *"$expected"* ]]; then
        echo "$result"
        echo "The clock does not match the prototype: expected $expected"
        exit 1
    fi
done

widths="$(sed -n 's/.*widths=\([0-9,]*\).*/\1/p' <<<"$result")"
if [[ -z "$widths" ]]; then
    echo "$result"
    echo "The walk measured nothing"
    exit 1
fi

# A centred clock is only as still as its widest and narrowest minute are alike.
IFS=',' read -r -a measured <<<"$widths"
for width in "${measured[@]}"; do
    if [[ "$width" -le 0 ]]; then
        echo "$result"
        echo "The time drew nothing"
        exit 1
    fi
    if [[ "$width" != "${measured[0]}" ]]; then
        echo "$result"
        echo "The clock changes width as the digits change"
        exit 1
    fi
done

echo "The clock renders at the prototype's metrics and holds its width: $result"
