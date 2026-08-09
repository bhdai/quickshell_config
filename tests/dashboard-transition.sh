#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/dashboard-transition"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/dashboard" "$test_dir/config/services" "$test_dir/library"

ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
for file in DashboardCard.qml DashTabBar.qml DashboardPane.qml CalendarCard.qml WeatherHeader.qml WeatherTiles.qml WeatherTile.qml HumidityWave.qml SunPath.qml WallpaperPane.qml WallpaperTile.qml PerformancePane.qml PerformanceCard.qml CpuCard.qml MemoryCard.qml NetworkCard.qml StorageCard.qml TimeseriesPlot.qml PlotKey.qml calendar_layout.js dashboard_metrics.js weather_tile_geometry.js timeseries_plot.js network_ceiling.js storage_gauge.js; do
    ln -s "$repo_root/modules/dashboard/$file" "$test_dir/config/modules/dashboard/$file"
done
ln -s "$repo_root/services/Weather.qml" "$test_dir/config/services/Weather.qml"
ln -s "$repo_root/services/weather_format.js" "$test_dir/config/services/weather_format.js"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
# The Performance cards read the resource ring, and an `import qs.services` compiles the
# whole directory, so the service arrives with the two libraries it parses through.
ln -s "$repo_root/services/ResourceUsage.qml" "$test_dir/config/services/ResourceUsage.qml"
ln -s "$repo_root/services/ResourceUsageParse.js" "$test_dir/config/services/ResourceUsageParse.js"
ln -s "$repo_root/services/cpu_temperature.js" "$test_dir/config/services/cpu_temperature.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

results=""
for scenario in skip retarget; do
    state_dir="$test_dir/state-$scenario"
    runtime_dir="$test_dir/runtime-$scenario"
    log="$test_dir/$scenario.log"
    mkdir -p "$state_dir/quickshell/user" "$runtime_dir"
    chmod 700 "$runtime_dir"
    printf '{"wallpaper":"","monitorWallpapers":{},"library":"%s"}\n' \
        "$test_dir/library" >"$state_dir/quickshell/user/wallpaper.json"

    if ! QT_QPA_PLATFORM=offscreen \
        WAYLAND_DISPLAY= \
        XDG_RUNTIME_DIR="$runtime_dir" \
        XDG_STATE_HOME="$state_dir" \
        DASHBOARD_TRANSITION_SCENARIO="$scenario" \
        timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
        cat "$log"
        echo "The dashboard transition fixture did not finish: $scenario"
        exit 1
    fi

    if grep -v 'quickshell\.ipc' "$log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign|MOTION FAIL'; then
        cat "$log"
        echo "The dashboard transition fixture failed: $scenario"
        exit 1
    fi

    results+="$(grep -o 'MOTION .*' "$log" || true)"$'\n'
done

for expected in \
    'MOTION SKIP prepared residents=dashboard,wallpaper,performance actual=0 target=-1548' \
    'MOTION SKIP inflight residents=dashboard,wallpaper,performance' \
    'MOTION SKIP settled card=896x524 actual=-1548 target=-1548 residents=performance' \
    'MOTION RETARGET prepared residents=dashboard,wallpaper actual=0 target=-872' \
    'MOTION RETARGET redirected residents=dashboard,wallpaper,performance target=-1548' \
    'MOTION RETARGET inflight residents=dashboard,wallpaper,performance' \
    'MOTION RETARGET settled card=896x524 actual=-1548 target=-1548 residents=performance'; do
    if ! grep -qF "$expected" <<<"$results"; then
        cat "$log"
        echo "The dashboard transition missed: $expected"
        exit 1
    fi
done

echo "The dashboard keeps each swept corridor resident through skip and retarget transitions"
