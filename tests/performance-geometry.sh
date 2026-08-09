#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/performance-geometry"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/dashboard" "$test_dir/config/services" \
    "$test_dir/library"

# DashboardCard declares every destination component, so its offscreen config needs their
# production import closure even though it starts directly on Performance.
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
for file in DashboardCard.qml DashTabBar.qml DashboardPane.qml CalendarCard.qml WeatherHeader.qml WeatherTiles.qml WeatherTile.qml HumidityWave.qml SunPath.qml WallpaperPane.qml WallpaperTile.qml PerformancePane.qml PerformanceCard.qml CpuCard.qml MemoryCard.qml NetworkCard.qml StorageCard.qml TimeseriesPlot.qml PlotKey.qml calendar_layout.js dashboard_metrics.js weather_tile_geometry.js timeseries_plot.js network_ceiling.js storage_gauge.js warning_state.js; do
    ln -s "$repo_root/modules/dashboard/$file" "$test_dir/config/modules/dashboard/$file"
done
ln -s "$repo_root/services/Weather.qml" "$test_dir/config/services/Weather.qml"
ln -s "$repo_root/services/weather_format.js" "$test_dir/config/services/weather_format.js"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
ln -s "$repo_root/services/ResourceUsageParse.js" "$test_dir/config/services/ResourceUsageParse.js"
# ResourceUsage is the only production seam replaced; every component that consumes it keeps
# its normal `import qs.services` and the real formatting library.
ln -s "$fixture_dir/ResourceUsage.qml" "$test_dir/config/services/ResourceUsage.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

results=""

run_case() {
    local profile="$1"
    local state_dir="$test_dir/state-$profile"
    local runtime_dir="$test_dir/runtime-$profile"
    local log="$test_dir/$profile.log"

    mkdir -p "$state_dir/quickshell/user" "$runtime_dir"
    chmod 700 "$runtime_dir"
    printf '{"wallpaper":"","monitorWallpapers":{},"library":"%s"}\n' \
        "$test_dir/library" >"$state_dir/quickshell/user/wallpaper.json"

    if ! QT_QPA_PLATFORM=offscreen \
        WAYLAND_DISPLAY= \
        XDG_RUNTIME_DIR="$runtime_dir" \
        XDG_STATE_HOME="$state_dir" \
        PERFORMANCE_GEOMETRY_PROFILE="$profile" \
        timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
        cat "$log"
        echo "The Performance geometry fixture did not finish: $profile"
        exit 1
    fi

    if grep -v 'quickshell\.ipc' "$log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign|PERFORMANCE FAIL'; then
        cat "$log"
        echo "The Performance geometry fixture failed: $profile"
        exit 1
    fi

    results+="$(grep -o 'PERFORMANCE .*' "$log" || true)"$'\n'
}

run_case complete
run_case cold-start

for expected in \
    'PERFORMANCE complete card=896x524 pane=872x428' \
    'PERFORMANCE complete cpu=0,0 430x208 memory=442,0 430x208 network=0,220 580x208 storage=592,220 280x208' \
    'PERFORMANCE complete history=2 plots=3 collecting=0 cpu-temperature=67°C critical=Critical 100°C swap=true download=1.5 MiB/s upload=256.0 KiB/s headlines=true,true,true'; do
    if ! grep -qF "$expected" <<<"$results"; then
        echo "$results"
        echo "The complete Performance profile missed: $expected"
        exit 1
    fi
done

for expected in \
    'PERFORMANCE cold-start card=896x524 pane=872x428' \
    'PERFORMANCE cold-start cpu=0,0 430x208 memory=442,0 430x208 network=0,220 580x208 storage=592,220 280x208' \
    'PERFORMANCE cold-start history=1 plots=3 collecting=3 collecting-cards=1,1,1 cpu-temperature=— critical= swap=false download=— upload=32.0 KiB/s headlines=true,true,true'; do
    if ! grep -qF "$expected" <<<"$results"; then
        echo "$results"
        echo "The cold-start Performance profile missed: $expected"
        exit 1
    fi
done

echo "The Performance destination holds its resting geometry across complete and cold-start data"
