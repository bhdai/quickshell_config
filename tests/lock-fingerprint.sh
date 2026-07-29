#!/usr/bin/env bash

# The fingerprint affordance is built only when a lock is raised, and its rejected and
# recognized treatments only when a reader has answered, so nothing else in CI ever
# constructs them. This builds it offscreen and walks it through all four states.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/lock-fingerprint"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/lock" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the
# affordance and what it imports and nothing else. The rest of the lock module pulls in the
# layer-shell surface, which cannot be built with no Wayland session to build it on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/modules/lock/LockFingerprint.qml" "$test_dir/config/modules/lock/LockFingerprint.qml"
ln -s "$repo_root/modules/lock/LockFingerprint.js" "$test_dir/config/modules/lock/LockFingerprint.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The fingerprint affordance did not load"
    exit 1
fi

if ! results="$(grep -o 'LOCK_FINGERPRINT .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The fingerprint affordance never finished constructing"
    exit 1
fi

# A binding that throws still leaves the object standing and the walk still logs, so the
# treatments below would all look right while the line rendered nothing. The IPC socket is
# not one of ours: quickshell fails to bind it when the runtime path is long, which says
# nothing about the QML.
if grep -v 'quickshell\.ipc' "$test_dir/quickshell.log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$test_dir/quickshell.log"
    echo "The fingerprint affordance loaded with errors"
    exit 1
fi

read_field() {
    sed -n "s/.*phase=$1 .*\<$2=\([^ ]*\).*/\1/p" <<<"$results"
}

# Absent covers no reader, no enrolment and a reader unplugged mid-lock alike, and an
# unknown state falls back to it. Nothing is offered in any of them.
for phase in absent a-fifth-state; do
    if [[ "$(read_field "$phase" visible)" != "false" ]]; then
        echo "$results"
        echo "The affordance drew itself in the $phase state"
        exit 1
    fi
done

for phase in armed rejected recognized; do
    if [[ "$(read_field "$phase" visible)" != "true" ]]; then
        echo "$results"
        echo "The affordance did not draw itself in the $phase state"
        exit 1
    fi
done

# A refusal that looks like the invitation to touch is a refusal the user does not read.
# The invitation and the refusal share an icon on purpose, so the colour is what has to
# carry it — this is the mapping as wired rather than as unit-tested.
looks="$(grep -E 'phase=(armed|rejected|recognized) ' <<<"$results" | sed -n 's/.*\(tone=[^ ]* icon=[^ ]* shake=[^ ]*\).*/\1/p')"
if [[ "$(sort -u <<<"$looks" | wc -l)" -ne 3 ]]; then
    echo "$results"
    echo "The three drawn states are not visibly distinct"
    exit 1
fi

if [[ "$(read_field rejected shake)" != "true" ]]; then
    echo "$results"
    echo "The refusal did not arrive with its jolt"
    exit 1
fi

if ! layout="$(grep -o 'LOCK_FINGERPRINT_LAYOUT .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The affordance never reported its size"
    exit 1
fi

# One line of text beside one icon. Zero means the row collapsed and the affordance is a
# hole in the composition rather than an offer to touch the reader.
width="$(sed -n 's/.*\<width=\([0-9]*\).*/\1/p' <<<"$layout")"
height="$(sed -n 's/.*\<height=\([0-9]*\).*/\1/p' <<<"$layout")"
if [[ -z "$width" || "$width" -lt 100 || -z "$height" || "$height" -lt 12 ]]; then
    echo "$layout"
    echo "The affordance did not lay out"
    exit 1
fi
