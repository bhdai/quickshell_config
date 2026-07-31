#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/wallpaper-service"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/config/modules/common" \
    "$test_dir/home/.config" "$test_dir/images" "$test_dir/library"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
ln -s "$repo_root/modules/common/functions" "$test_dir/config/modules/common/functions"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -d >"$test_dir/images/first.png"
cp "$test_dir/images/first.png" "$test_dir/images/second.png"
printf '%s\n' 'not an image' >"$test_dir/images/bad.png"

cp "$test_dir/images/first.png" "$test_dir/library/z.PNG"
cp "$test_dir/images/first.png" "$test_dir/library/a.jpg"
cp "$test_dir/images/first.png" "$test_dir/library/m.jpeg"
cp "$test_dir/images/first.png" "$test_dir/library/b.BMP"
cp "$test_dir/images/first.png" "$test_dir/library/ignored.webp"
mkdir "$test_dir/library/directory.png"

printf 'XDG_PICTURES_DIR="%s"\n' "$test_dir/home/Pictures" >"$test_dir/home/.config/user-dirs.dirs"

run_case() {
    local scenario="$1"
    local state_dir="$test_dir/state-$scenario"
    local runtime_dir="$test_dir/runtime-$scenario"
    local log="$test_dir/$scenario.log"

    mkdir -p "$state_dir/quickshell/user" "$runtime_dir"
    chmod 700 "$runtime_dir"

    if ! HOME="$test_dir/home" \
        XDG_CONFIG_HOME="$test_dir/home/.config" \
        XDG_RUNTIME_DIR="$runtime_dir" \
        XDG_STATE_HOME="$state_dir" \
        WALLPAPER_TEST_SCENARIO="$scenario" \
        WALLPAPER_TEST_GOOD="$test_dir/images/first.png" \
        WALLPAPER_TEST_SECOND="$test_dir/images/second.png" \
        WALLPAPER_TEST_BAD="$test_dir/images/bad.png" \
        WALLPAPER_TEST_INSERTED="$test_dir/library/c.png" \
        QT_QPA_PLATFORM=offscreen \
        WAYLAND_DISPLAY= \
        timeout 8 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
        cat "$log"
        echo "Wallpaper fixture failed in scenario: $scenario"
        exit 1
    fi

    if grep -v 'quickshell\.ipc' "$log" \
        | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign|timeout scenario='; then
        cat "$log"
        echo "Wallpaper fixture logged an error in scenario: $scenario"
        exit 1
    fi
}

run_case missing
missing_state="$test_dir/state-missing/quickshell/user/wallpaper.json"
if [[ -e "$missing_state" ]]; then
    echo "Missing wallpaper state was materialized before a choice"
    exit 1
fi
grep -qF "WALLPAPER_RESULT missing get= library=$test_dir/home/Pictures/wall" "$test_dir/missing.log"

run_case commit
commit_state="$test_dir/state-commit/quickshell/user/wallpaper.json"
grep -qF "WALLPAPER_PENDING relative= unsupported= home=$test_dir/home/missing.JPG accepted=$test_dir/images/first.png current=" "$test_dir/commit.log"
grep -qF "WALLPAPER_RESULT committed=$test_dir/images/first.png" "$test_dir/commit.log"
state_keys="$(grep -oE '"[^"]+"[[:space:]]*:' "$commit_state" \
    | sed -E 's/[":[:space:]]//g' | sort)"
[[ "$state_keys" == $'library\nmonitorWallpapers\nwallpaper' ]]
grep -qF "\"wallpaper\": \"$test_dir/images/first.png\"" "$commit_state"
grep -qE '"monitorWallpapers"[[:space:]]*:[[:space:]]*\{' "$commit_state"
grep -qF "\"library\": \"$test_dir/home/Pictures/wall\"" "$commit_state"

reload_state="$test_dir/state-reload/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$reload_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$reload_state"
run_case reload
grep -qF "WALLPAPER_INITIAL $test_dir/images/first.png" "$test_dir/reload.log"
grep -qF "WALLPAPER_RESULT reloaded=$test_dir/images/second.png" "$test_dir/reload.log"

malformed_state="$test_dir/state-malformed/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$malformed_state")"
printf '%s' '{ "wallpaper": ' >"$malformed_state"
malformed_before="$(sha256sum "$malformed_state")"
run_case malformed
grep -qF "WALLPAPER_RESULT malformed accepted= current=" "$test_dir/malformed.log"
grep -qF "Wallpaper: malformed state; refusing writes for this session" "$test_dir/malformed.log"
[[ "$(sha256sum "$malformed_state")" == "$malformed_before" ]]

malformed_reload_state="$test_dir/state-malformed-reload/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$malformed_reload_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$malformed_reload_state"
run_case malformed-reload
grep -qF "WALLPAPER_RESULT malformed-reload accepted= current=" "$test_dir/malformed-reload.log"
grep -qF "Wallpaper: malformed state; refusing writes for this session" "$test_dir/malformed-reload.log"
grep -qF '{ "wallpaper": ' "$malformed_reload_state"

validation_state="$test_dir/state-validation/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$validation_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$validation_state"
run_case validation
grep -qF "WALLPAPER_BAD accepted=$test_dir/images/bad.png current=$test_dir/images/first.png" "$test_dir/validation.log"
grep -qF "WALLPAPER_AFTER_BAD $test_dir/images/first.png" "$test_dir/validation.log"
grep -qF "WALLPAPER_LATEST first=$test_dir/images/first.png second=$test_dir/images/second.png current=$test_dir/images/first.png" "$test_dir/validation.log"
grep -qF "WALLPAPER_RESULT latest=$test_dir/images/second.png" "$test_dir/validation.log"

same_path_state="$test_dir/state-same-path/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$same_path_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/bad.png" "$test_dir/library" >"$same_path_state"
run_case same-path
grep -qF "WALLPAPER_RESULT same-path=$test_dir/images/bad.png" "$test_dir/same-path.log"
grep -qF "Wallpaper: image decode failed: $test_dir/images/bad.png" "$test_dir/same-path.log"

library_state="$test_dir/state-library/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$library_state")"
printf '{"wallpaper":"","monitorWallpapers":{},"library":"%s"}\n' "$test_dir/library" >"$library_state"
run_case library
grep -qF "WALLPAPER_LIBRARY initial=a.jpg,b.BMP,m.jpeg,z.PNG" "$test_dir/library.log"
grep -qF "WALLPAPER_RESULT library=a.jpg,b.BMP,c.png,m.jpeg,z.PNG" "$test_dir/library.log"

echo "Wallpaper state, validation, and live library behavior passed"
