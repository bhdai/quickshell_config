#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/dashboard-wallpaper-interaction"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/dashboard" "$test_dir/config/services" \
    "$test_dir/config/scripts/colors" "$test_dir/library" \
    "$test_dir/state/quickshell/user" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/assets" "$test_dir/config/assets"
for file in DashboardCard.qml DashTabBar.qml CalendarPane.qml CalendarCard.qml WeatherHeader.qml WeatherTiles.qml WeatherTile.qml HumidityWave.qml WallpaperPane.qml WallpaperTile.qml calendar_layout.js dashboard_metrics.js weather_tile_geometry.js; do
    ln -s "$repo_root/modules/dashboard/$file" "$test_dir/config/modules/dashboard/$file"
done
ln -s "$repo_root/services/Weather.qml" "$test_dir/config/services/Weather.qml"
ln -s "$repo_root/services/weather_format.js" "$test_dir/config/services/weather_format.js"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
ln -s "$repo_root/tests/fixtures/wallpaper-service/apply-colors.sh" \
    "$test_dir/config/scripts/colors/apply-colors.sh"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -d >"$test_dir/pixel.png"
for index in $(seq -w 1 18); do
    cp "$test_dir/pixel.png" "$test_dir/library/$index.png"
done

printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/library/18.png" "$test_dir/library" \
    >"$test_dir/state/quickshell/user/wallpaper.json"
: >"$test_dir/colors.log"

if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    XDG_STATE_HOME="$test_dir/state" \
    WALLPAPER_INTERACTION_PIXEL="$test_dir/pixel.png" \
    WALLPAPER_TEST_COLOR_LOG="$test_dir/colors.log" \
    timeout 30 qs --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    exit 1
fi

if grep -v 'quickshell\.ipc' "$test_dir/quickshell.log" \
        | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$test_dir/quickshell.log"
    exit 1
fi

if ! grep -qF 'WALLPAPER_INTERACTION passed' "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "The wallpaper interaction fixture did not complete"
    exit 1
fi

echo "Wallpaper keyboard and live-library interactions passed"
