#!/usr/bin/env bash

# The status cluster must never be able to hold the lock screen up. The case that proves it
# is UPower being unreachable: the battery slot has nothing to say, and everything else has
# to carry on regardless.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/lock-status-cluster"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/lock" "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree is assembled from
# the cluster's actual dependencies. Handing it the whole repo would drag in the layer-shell
# surfaces, which cannot be built with no Wayland session to build them on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/modules/lock/LockStatusCluster.qml" "$test_dir/config/modules/lock/LockStatusCluster.qml"
ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

for service in Battery.qml BatteryFormat.js Network.qml NetworkParse.js WifiAccessPoint.qml \
    KeyboardLayout.qml KeyboardLayoutParse.js Lock.qml LockLogic.js; do
    ln -s "$repo_root/services/$service" "$test_dir/config/services/$service"
done

if ! DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_dir/no-system-bus" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The status cluster did not load with UPower unavailable"
    exit 1
fi

if ! result="$(grep -o 'LOCK_STATUS_CLUSTER .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The status cluster never finished constructing"
    exit 1
fi

if [[ "$result" != *"battery=false"* ]]; then
    cat "$test_dir/quickshell.log"
    echo "UPower was expected to be unavailable in this run: $result"
    exit 1
fi

# Absence is ambiguous for a network, so the icon renders whatever the answer is. A cluster
# with no battery to show still has to be wider than nothing.
width="$(sed -n 's/.*width=\([0-9]*\).*/\1/p' <<<"$result")"
if [[ -z "$width" || "$width" -le 0 ]]; then
    cat "$test_dir/quickshell.log"
    echo "The network icon took no width: $result"
    exit 1
fi

if [[ "$result" != *"symbol=network-"* ]]; then
    cat "$test_dir/quickshell.log"
    echo "The network symbol did not come from the shared selection: $result"
    exit 1
fi
