#!/usr/bin/env bash

# The password prompt is built only when a lock is raised, and its failure treatments only
# when authentication has already failed, so nothing else in CI ever constructs them. This
# builds the prompt offscreen and walks it through all six states.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/lock-auth-area"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/lock" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the prompt
# and what it imports and nothing else. The rest of the lock module pulls in the layer-shell
# surface, which cannot be built with no Wayland session to build it on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/modules/lock/LockAuthArea.qml" "$test_dir/config/modules/lock/LockAuthArea.qml"
ln -s "$repo_root/modules/lock/LockAuth.js" "$test_dir/config/modules/lock/LockAuth.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The password prompt did not load"
    exit 1
fi

if ! results="$(grep -o 'LOCK_AUTH_AREA .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The password prompt never finished constructing"
    exit 1
fi

# A binding that throws still leaves the object standing and the walk still logs, so the
# treatments below would all look right while the field rendered nothing. The IPC socket is
# not one of ours: quickshell fails to bind it when the runtime path is long, which says
# nothing about the QML.
if grep -v 'quickshell\.ipc' "$test_dir/quickshell.log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$test_dir/quickshell.log"
    echo "The password prompt loaded with errors"
    exit 1
fi

if [[ "$(wc -l <<<"$results")" -ne 6 ]]; then
    echo "$results"
    echo "The walk did not reach all six states"
    exit 1
fi

read_field() {
    sed -n "s/.*step=$1 .*\<$2=\([^ ]*\).*/\1/p" <<<"$results"
}

# Each state is reached through the properties the surface actually binds, so this is the
# mapping as wired rather than as unit-tested.
for expected in idle:idle typing:typing authenticating:authenticating rejected:rejected maxTries:tooManyAttempts unavailable:unavailable; do
    step="${expected%%:*}"
    state="${expected##*:}"
    if [[ "$(read_field "$step" state)" != "$state" ]]; then
        echo "$results"
        echo "Step $step did not reach $state"
        exit 1
    fi
done

# The three failures call for three different actions, so they must not be three renderings
# of the same treatment.
looks="$(grep -E 'step=(rejected|maxTries|unavailable) ' <<<"$results" | sed -n 's/.*\(tone=.*\)$/\1/p')"
if [[ "$(sort -u <<<"$looks" | wc -l)" -ne 3 ]]; then
    echo "$results"
    echo "The three failure treatments are not visibly distinct"
    exit 1
fi

if [[ "$(read_field authenticating spin)" != "true" || "$(read_field rejected shake)" != "true" ]]; then
    echo "$results"
    echo "The progress and rejection treatments did not arrive"
    exit 1
fi

height="$(read_field idle height)"
if [[ -z "$height" || "$height" -lt 56 ]]; then
    echo "$results"
    echo "The prompt did not lay out: $results"
    exit 1
fi
