#!/usr/bin/env bash

# The bar's battery indicator and its hover readout, built against the live Battery singleton.
# The shared body declares its state as required properties, so an indicator that stops
# supplying one fails to load rather than drawing something wrong.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/battery-indicator"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/bar" "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the bar is assembled from just
# the battery's own files. The whole bar would drag in the layer-shell surfaces, which cannot
# be built with no Wayland session to build them on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
for file in BatteryIndicator.qml BatteryDetails.qml; do
    ln -s "$repo_root/modules/bar/$file" "$test_dir/config/modules/bar/$file"
done
for service in Battery.qml battery_glyph.js Time.qml; do
    ln -s "$repo_root/services/$service" "$test_dir/config/services/$service"
done
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_dir/no-system-bus" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The battery indicator did not build"
    exit 1
fi

if ! result="$(grep -o 'BATTERY_INDICATOR .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The battery indicator never finished constructing"
    exit 1
fi

width="$(sed -n 's/.*width=\([0-9]*\).*/\1/p' <<<"$result")"
if [[ -z "$width" || "$width" -le 0 ]]; then
    echo "the indicator took no width: $result"
    exit 1
fi

# The hover readout is a rich tooltip's content and is built on demand, so nothing else would
# notice it failing to construct until the pointer landed on the battery.
details_height="$(sed -n 's/.*detailsHeight=\([0-9]*\).*/\1/p' <<<"$result")"
if [[ -z "$details_height" || "$details_height" -le 0 ]]; then
    echo "the hover readout laid out to nothing: $result"
    exit 1
fi
