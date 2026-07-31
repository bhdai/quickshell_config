#!/usr/bin/env bash

# The dashboard's contract is a size. A calendar that grew a row, a longer condition string,
# or a tile that reflowed would all break it in ways source assertions cannot see, so this
# renders the real card and measures it.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/dashboard-geometry"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/dashboard" "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the card and
# what it imports and nothing else. Dashboard.qml is left out: it raises the layer-shell
# window, which cannot be built with no Wayland session to build it on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
for file in DashboardCard.qml DashTabBar.qml CalendarPane.qml CalendarCard.qml WeatherHeader.qml WeatherTiles.qml WeatherTile.qml calendar_layout.js dashboard_metrics.js; do
    ln -s "$repo_root/modules/dashboard/$file" "$test_dir/config/modules/dashboard/$file"
done
# The weather library sits beside its service, which is where the tiles import it from.
ln -s "$repo_root/services/Weather.qml" "$test_dir/config/services/Weather.qml"
ln -s "$repo_root/services/weather_format.js" "$test_dir/config/services/weather_format.js"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The dashboard did not load"
    exit 1
fi

if ! results="$(grep -o 'DASHBOARD .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The dashboard never finished constructing"
    exit 1
fi

# A binding that throws still leaves the object standing and the measurement still logs, so a
# broken weather binding would look like a card that simply drew nothing. The IPC socket is
# not one of ours: quickshell fails to bind it when the runtime path is long. A weather fetch
# has no network here and warns; that is the service behaving, not a defect.
if grep -v 'quickshell\.ipc' "$test_dir/quickshell.log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$test_dir/quickshell.log"
    echo "The dashboard loaded with errors"
    exit 1
fi

# #96's canvas, and the composition derived from it: a full-width 72px band over a 347px body
# of two equal 332px columns, with the calendar's natural height fitting the body it is given
# rather than being compressed into it.
for expected in "card=700x507" \
    "pane=676x427" \
    "band=676x72" \
    "calendar=0,80 332x347" \
    "tiles=344,80 332x347" \
    "natural=347" \
    "cells=42 rows=6" \
    "today=28@0"; do
    if ! grep -qF "$expected" <<<"$results"; then
        echo "$results"
        echo "The dashboard does not match the accepted geometry: expected $expected"
        exit 1
    fi
done

# Every month is six rows and the Today control is opacity-gated, so navigating cannot change
# a single one of those numbers.
if ! grep -qF "navigated=700x507,700x507,700x507 today=28@1 natural=347" <<<"$results"; then
    echo "$results"
    echo "The dashboard resized while navigating months"
    exit 1
fi

echo "The dashboard holds its geometry through month navigation:"
echo "$results"
