#!/usr/bin/env bash

# The dashboard's contract is a size per destination. A calendar that grew a row, a longer
# condition string, a tile that reflowed, or a wallpaper grid that stretched its cells to fill
# a sparse row would all break it in ways source assertions cannot see, so this renders the
# real card and measures it — on both tabs, which are deliberately not the same size.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/dashboard-geometry"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/dashboard" "$test_dir/config/services" \
    "$test_dir/full-library" "$test_dir/sparse-library" "$test_dir/empty-library"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the card and
# what it imports and nothing else. Dashboard.qml is left out: it raises the layer-shell
# window, which cannot be built with no Wayland session to build it on.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
for file in DashboardCard.qml DashTabBar.qml DashboardPane.qml CalendarCard.qml WeatherHeader.qml WeatherTiles.qml WeatherTile.qml HumidityWave.qml SunPath.qml WallpaperPane.qml WallpaperTile.qml PerformancePane.qml PerformanceCard.qml CpuCard.qml MemoryCard.qml NetworkCard.qml StorageCard.qml TimeseriesPlot.qml PlotKey.qml calendar_layout.js dashboard_metrics.js weather_tile_geometry.js timeseries_plot.js network_ceiling.js storage_gauge.js warning_state.js; do
    ln -s "$repo_root/modules/dashboard/$file" "$test_dir/config/modules/dashboard/$file"
done
# The weather library sits beside its service, which is where the tiles import it from.
ln -s "$repo_root/services/Weather.qml" "$test_dir/config/services/Weather.qml"
ln -s "$repo_root/services/weather_format.js" "$test_dir/config/services/weather_format.js"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
# Time.qml refreshes its clock off SystemSleep, so a config with one and not the other
# throws on load rather than merely losing the refresh.
ln -s "$repo_root/services/SystemSleep.qml" "$test_dir/config/services/SystemSleep.qml"
ln -s "$repo_root/services/SystemSleepParse.js" "$test_dir/config/services/SystemSleepParse.js"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
# The Performance cards read the resource ring, and an `import qs.services` compiles the
# whole directory, so the service arrives with the two libraries it parses through.
ln -s "$repo_root/services/ResourceUsage.qml" "$test_dir/config/services/ResourceUsage.qml"
ln -s "$repo_root/services/ResourceUsageParse.js" "$test_dir/config/services/ResourceUsageParse.js"
ln -s "$repo_root/services/cpu_temperature.js" "$test_dir/config/services/cpu_temperature.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

# A 1x1 PNG. What is being measured is where a cell sits, not what is in it.
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -d >"$test_dir/pixel.png"
# One more than the sixteen the pane can show, so the grid has to scroll rather than shrink.
for index in $(seq -w 1 20); do
    cp "$test_dir/pixel.png" "$test_dir/full-library/$index.png"
done
cp "$test_dir/pixel.png" "$test_dir/sparse-library/a.png"
cp "$test_dir/pixel.png" "$test_dir/sparse-library/b.png"

results=""

run_case() {
    local scenario="$1"
    local wallpaper="${2:-}"
    local state_dir="$test_dir/state-$scenario"
    local runtime_dir="$test_dir/runtime-$scenario"
    local log="$test_dir/$scenario.log"

    mkdir -p "$state_dir/quickshell/user" "$runtime_dir"
    chmod 700 "$runtime_dir"
    printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
        "$wallpaper" "$test_dir/$scenario-library" >"$state_dir/quickshell/user/wallpaper.json"

    # Timed out rather than left to run: a measurement that throws never reaches Qt.quit(),
    # and an offscreen shell with nothing to draw to will happily sit there forever.
    if ! QT_QPA_PLATFORM=offscreen \
        WAYLAND_DISPLAY= \
        XDG_RUNTIME_DIR="$runtime_dir" \
        XDG_STATE_HOME="$state_dir" \
        timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
        cat "$log"
        echo "The dashboard did not load in scenario: $scenario"
        exit 1
    fi

    # A binding that throws still leaves the object standing and the measurement still logs, so
    # a broken weather binding would look like a card that simply drew nothing. The IPC socket
    # is not one of ours: quickshell fails to bind it when the runtime path is long. A weather
    # fetch has no network here and warns; that is the service behaving, not a defect.
    if grep -v 'quickshell\.ipc' "$log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
        cat "$log"
        echo "The dashboard loaded with errors in scenario: $scenario"
        exit 1
    fi

    if ! results="$(grep -o 'DASHBOARD .*\|TABS .*\|GRID .*' "$log")"; then
        cat "$log"
        echo "The dashboard never finished constructing in scenario: $scenario"
        exit 1
    fi
}

expect() {
    local scenario="$1"
    shift
    for expected in "$@"; do
        if ! grep -qF "$expected" <<<"$results"; then
            echo "$results"
            echo "The dashboard does not match the accepted geometry in $scenario: expected $expected"
            exit 1
        fi
    done
}

run_case full "$test_dir/full-library/03.png"

# The calendar's own canvas: a full-width 72px band over a 348px body of a 332px calendar and
# a 528px tile column, which is what six square tiles need three abreast. The body is the
# number the two columns have to agree on, so the tile edge and the calendar's six week rows
# are both checked against it here.
expect full \
    "card=896x524" \
    "pane=872x428" \
    "band=872x72" \
    "calendar=0,80 332x348" \
    "tiles=344,80 528x348" \
    "tilecount=6 tilesizes=168x168" \
    "cells=42 rows=6" \
    "today=28@0" \
    "cellwidths=44"

# The band anchors its date to one edge and its reading to the other with nothing between
# them, so a destination narrow enough to overlap them shows up as a gap at or below zero.
bandgap="$(grep -o 'bandgap=-\?[0-9]*' <<<"$results" | head -1 | cut -d= -f2)"
if ((bandgap < 24)); then
    echo "$results"
    echo "The weather band has no room between its date and its reading: bandgap=$bandgap"
    exit 1
fi

# A month is only a grid if every day sits under its own heading. Cells left to fill keep
# their own implicit width first and split only the leftover, which gives a two-digit day, a
# one-digit day and a weekday label three different widths — measured here as twelve distinct
# cell widths and two column runs that disagree from the second column on. Both sides are
# reported as left edges within the card so a failure shows which way they drifted.
columns="$(grep -o 'columns=[0-9,]*' <<<"$results" | head -1 | cut -d= -f2)"
headings="$(grep -o 'headings=[0-9,]*' <<<"$results" | head -1 | cut -d= -f2)"
if [[ "$columns" != "$headings" ]]; then
    echo "$results"
    echo "The day columns do not line up under the weekday headings:"
    echo "  columns  $columns"
    echo "  headings $headings"
    exit 1
fi

# What the calendar column wants, against the 348 it is given. It has to fit rather than be
# compressed into place — restoring the Today row's old 4px top margin puts it at 351, which
# is the regression this catches.
#
# Not pinned to a single number: the weekday labels are the one row here whose height comes
# from font metrics, so the natural height is a couple of pixels under the body in a bare
# container. Only the ceiling is the contract. The floor is loose and exists so that a
# calendar which lost a row fails here too rather than passing for being small.
for natural in $(grep -o 'natural=[0-9.]*' <<<"$results" | cut -d= -f2); do
    if ! awk -v n="$natural" 'BEGIN { exit !(n <= 348 && n > 330) }'; then
        echo "$results"
        echo "The calendar column does not fit its 348px body: natural=$natural"
        exit 1
    fi
done

# Every month is six rows and the Today control is opacity-gated, so navigating cannot change
# a single one of those numbers. The card resizes between destinations and nowhere else.
if ! grep -qF "navigated=896x524,896x524,896x524 today=28@1" <<<"$results"; then
    echo "$results"
    echo "The dashboard resized while navigating months"
    exit 1
fi

# The same calendar before and after, so navigation cannot quietly change what the column
# wants either.
if [[ "$(grep -o 'natural=[0-9.]*' <<<"$results" | sort -u | wc -l)" != 1 ]]; then
    echo "$results"
    echo "The calendar column changed height while navigating months"
    exit 1
fi

# Two equal icon-over-label targets across the row, at M3's 64px for a two-line tab. The row
# is as wide as the card it is in, so the two destinations put the same tabs at different
# widths.
expect full \
    "TABS height=64 widths=436,436" \
    "TABS height=64 widths=338,338"

# TABBAR_H is 64 because a 24px icon over a 15px label measures 49 and is given 6px above and
# below plus the indicator's 3px lane. The content is centred in the bar rather than padded to
# it, so font metrics that drifted far from 49 would silently move that padding instead of
# failing. Only the span is the contract; the exact number comes from the font.
for lines in $(grep -o 'lines=[0-9]*' <<<"$results" | cut -d= -f2); do
    if ((lines < 45 || lines > 53)); then
        echo "$results"
        echo "The tab's two lines no longer fit the 6px above and below that make the bar 64: lines=$lines"
        exit 1
    fi
done

# The indicator has to hug the wider of a tab's two rendered lines rather than the cell, and
# no two tabs draw the same width, so this compares the two measured segments rather than
# pinning numbers that come from font metrics. Both tabs are checked because an indicator
# bound to the first cell would look correct on Dashboard and wrong nowhere else.
indicators=()
while read -r indicator active; do
    indicators+=("$indicator")
    if [[ "${indicator%@*}" != "$active" ]]; then
        echo "$results"
        echo "The tab indicator is not on its label: indicator=${indicator%@*} label=$active"
        exit 1
    fi
    if [[ "${indicator##*@}" != 3 ]]; then
        echo "$results"
        echo "The tab indicator is not 3px tall: $indicator"
        exit 1
    fi
done < <(grep -o 'indicator=[^ ]* active=[^ ]*' <<<"$results" | sed 's/indicator=//; s/ active=/ /')

if [[ "${#indicators[@]}" != 2 || "${indicators[0]}" == "${indicators[1]}" ]]; then
    echo "$results"
    echo "The tab indicator did not move with the active tab: ${indicators[*]}"
    exit 1
fi

# Switching to the picker is what per-destination sizing is for: a card of the picker's own
# width, four 160x100 cells to a row at the accepted gaps, four rows of them visible, and the
# twenty-image library scrolling rather than compressing to fit.
expect full \
    "GRID card=700x520 pane=676x424" \
    "viewport=676x424 content=532" \
    "tiles=20 sizes=160x100" \
    "columns=0,172,344,516" \
    "rows=0,108,216,324,432" \
    "applied=1:$test_dir/full-library/03.png" \
    "empty=false"

# The library holds two images and the applied wallpaper is not one of them. That is a
# supported state, not a missing tile: nothing is synthesized for it and no cell stretches to
# fill the row it left half empty.
run_case sparse "$test_dir/pixel.png"

expect sparse \
    "GRID card=700x520 pane=676x424" \
    "viewport=676x424 content=100" \
    "tiles=2 sizes=160x100" \
    "columns=0,172" \
    "rows=0" \
    "applied=0:" \
    "empty=false"

run_case empty

# One message, and it has to say which directory was looked in and what would have counted.
expect empty \
    "GRID card=700x520 pane=676x424" \
    "tiles=0" \
    "empty=true" \
    "$test_dir/empty-library" \
    '*.jpg, *.jpeg, *.png, *.bmp'

echo "The dashboard holds each destination's geometry across month navigation and both tabs"
