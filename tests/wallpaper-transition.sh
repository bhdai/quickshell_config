#!/usr/bin/env bash

set -euo pipefail

: "${WAYLAND_DISPLAY:?requires a running Wayland compositor}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/wallpaper-transition"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules" "$test_dir/config/services" \
    "$test_dir/config/scripts/colors" "$test_dir/home/.config" \
    "$test_dir/images" "$test_dir/state"
ln -s "$repo_root/modules/common" "$test_dir/config/modules/common"
ln -s "$repo_root/modules/wallpaper" "$test_dir/config/modules/wallpaper"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
ln -s /usr/bin/true "$test_dir/config/scripts/colors/apply-colors.sh"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -d >"$test_dir/images/leaves.png"
cp "$test_dir/images/leaves.png" "$test_dir/images/mountains.png"
printf 'XDG_PICTURES_DIR="%s"\n' "$test_dir/home/Pictures" >"$test_dir/home/.config/user-dirs.dirs"

log="$test_dir/transition.log"
if ! HOME="$test_dir/home" \
    XDG_CONFIG_HOME="$test_dir/home/.config" \
    XDG_STATE_HOME="$test_dir/state" \
    WALLPAPER_TEST_FIRST="$test_dir/images/leaves.png" \
    WALLPAPER_TEST_SECOND="$test_dir/images/mountains.png" \
    timeout 8 qs --no-color -p "$test_dir/config" >"$log" 2>&1; then
    cat "$log"
    exit 1
fi

if ! grep -qF "WALLPAPER_TRANSITION_RESULT target=$test_dir/images/leaves.png displayed=$test_dir/images/leaves.png loading= transitioning=false" "$log"; then
    cat "$log"
    exit 1
fi

echo "Wallpaper surfaces complete repeated transitions"
