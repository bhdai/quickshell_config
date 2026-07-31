#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/wallpaper-service"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/config/modules/common" \
    "$test_dir/config/scripts/colors" "$test_dir/bin" \
    "$test_dir/home/.config" "$test_dir/images" "$test_dir/library" \
    "$test_dir/empty-library" "$test_dir/one-library"
ln -s "$repo_root/services/Wallpaper.qml" "$test_dir/config/services/Wallpaper.qml"
ln -s "$repo_root/services/WallpaperLogic.js" "$test_dir/config/services/WallpaperLogic.js"
ln -s "$repo_root/modules/common/functions" "$test_dir/config/modules/common/functions"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"
ln -s "$fixture_dir/apply-colors.sh" "$test_dir/config/scripts/colors/apply-colors.sh"
ln -s "$fixture_dir/notify-send" "$test_dir/bin/notify-send"

printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -d >"$test_dir/images/first.png"
cp "$test_dir/images/first.png" "$test_dir/images/second.png"
cp "$test_dir/images/first.png" "$test_dir/images/third.png"
printf '%s\n' 'not an image' >"$test_dir/images/bad.png"

cp "$test_dir/images/first.png" "$test_dir/library/z.PNG"
cp "$test_dir/images/first.png" "$test_dir/library/a.jpg"
cp "$test_dir/images/first.png" "$test_dir/library/m.jpeg"
cp "$test_dir/images/first.png" "$test_dir/library/b.BMP"
cp "$test_dir/images/first.png" "$test_dir/library/ignored.webp"
mkdir "$test_dir/library/directory.png"
cp "$test_dir/images/first.png" "$test_dir/one-library/only.png"

printf 'XDG_PICTURES_DIR="%s"\n' "$test_dir/home/Pictures" >"$test_dir/home/.config/user-dirs.dirs"

run_case() {
    local scenario="$1"
    local state_dir="$test_dir/state-$scenario"
    local runtime_dir="$test_dir/runtime-$scenario"
    local log="$test_dir/$scenario.log"
    local color_log="$test_dir/$scenario-colors.log"
    local notify_log="$test_dir/$scenario-notifications.log"
    local color_delay=0.05
    local color_fail=

    if [[ "$scenario" == "palette-latest" ]]; then
        color_delay=0.4
    elif [[ "$scenario" == "palette-failure" ]]; then
        color_fail="$test_dir/images/second.png"
    fi

    mkdir -p "$state_dir/quickshell/user" "$runtime_dir"
    chmod 700 "$runtime_dir"

    if ! PATH="$test_dir/bin:$PATH" \
        HOME="$test_dir/home" \
        XDG_CONFIG_HOME="$test_dir/home/.config" \
        XDG_RUNTIME_DIR="$runtime_dir" \
        XDG_STATE_HOME="$state_dir" \
        WALLPAPER_TEST_SCENARIO="$scenario" \
        WALLPAPER_TEST_GOOD="$test_dir/images/first.png" \
        WALLPAPER_TEST_SECOND="$test_dir/images/second.png" \
        WALLPAPER_TEST_THIRD="$test_dir/images/third.png" \
        WALLPAPER_TEST_BAD="$test_dir/images/bad.png" \
        WALLPAPER_TEST_INSERTED="$test_dir/library/c.png" \
        WALLPAPER_TEST_COLOR_LOG="$color_log" \
        WALLPAPER_TEST_COLOR_DELAY="$color_delay" \
        WALLPAPER_TEST_COLOR_FAIL="$color_fail" \
        WALLPAPER_TEST_NOTIFY_LOG="$notify_log" \
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
grep -qF "WALLPAPER_RELOADED global=$test_dir/images/second.png resolved=$test_dir/images/second.png" "$test_dir/reload.log"
grep -qF "WALLPAPER_RESULT reloaded=$test_dir/images/second.png override=$test_dir/images/first.png" "$test_dir/reload.log"

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

cycle_state="$test_dir/state-cycle/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$cycle_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/second.png" "$test_dir/library" >"$cycle_state"
run_case cycle
grep -qF "WALLPAPER_CYCLE next=$test_dir/library/a.jpg current=$test_dir/images/second.png" "$test_dir/cycle.log"
grep -qF "WALLPAPER_CYCLE prev=$test_dir/library/z.PNG current=$test_dir/library/a.jpg" "$test_dir/cycle.log"
grep -qF "WALLPAPER_CYCLE wrap=$test_dir/library/a.jpg current=$test_dir/library/z.PNG" "$test_dir/cycle.log"
grep -qF "WALLPAPER_RESULT cycle=$test_dir/library/a.jpg" "$test_dir/cycle.log"

override_set_state="$test_dir/state-override-set/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$override_set_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$override_set_state"
run_case override-set
grep -qF "WALLPAPER_OVERRIDE pending invalid= bad=$test_dir/images/bad.png current=$test_dir/images/first.png" "$test_dir/override-set.log"
grep -qF "WALLPAPER_OVERRIDE after-bad=$test_dir/images/first.png accepted=$test_dir/images/second.png" "$test_dir/override-set.log"
grep -qF "WALLPAPER_RESULT override=$test_dir/images/second.png global=$test_dir/images/first.png" "$test_dir/override-set.log"
grep -qF "Wallpaper: monitor DP-1 is not connected; connected screens:" "$test_dir/override-set.log"
grep -qF "\"wallpaper\": \"$test_dir/images/first.png\"" "$override_set_state"
grep -qF "\"DP-1\": \"$test_dir/images/second.png\"" "$override_set_state"

override_clear_state="$test_dir/state-override-clear/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$override_clear_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{"DP-1":"%s","orphan":"%s"},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/images/second.png" \
    "$test_dir/images/second.png" "$test_dir/library" >"$override_clear_state"
run_case override-clear
grep -qF "WALLPAPER_RESULT clear=$test_dir/images/first.png resolved=$test_dir/images/first.png again=" "$test_dir/override-clear.log"
if grep -qF '"DP-1"' "$override_clear_state"; then
    echo "Cleared wallpaper override was retained"
    exit 1
fi
grep -qF "\"orphan\": \"$test_dir/images/second.png\"" "$override_clear_state"

override_no_fallback_state="$test_dir/state-override-no-fallback/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$override_no_fallback_state")"
printf '{"wallpaper":"","monitorWallpapers":{"DP-1":"%s"},"library":"%s"}\n' \
    "$test_dir/images/second.png" "$test_dir/library" >"$override_no_fallback_state"
run_case override-no-fallback
grep -qF "WALLPAPER_RESULT clear-no-fallback= resolved=" "$test_dir/override-no-fallback.log"
if grep -qF '"DP-1"' "$override_no_fallback_state"; then
    echo "Wallpaper override with no fallback was retained"
    exit 1
fi

hidden_global_state="$test_dir/state-hidden-global/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$hidden_global_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$hidden_global_state"
run_case hidden-global
grep -qF "WALLPAPER_HIDDEN accepted=$test_dir/images/second.png current=$test_dir/images/first.png" "$test_dir/hidden-global.log"
grep -qF "WALLPAPER_RESULT hidden=$test_dir/images/second.png" "$test_dir/hidden-global.log"
grep -qF "Wallpaper: every connected screen" "$test_dir/hidden-global.log"
grep -qF "\"wallpaper\": \"$test_dir/images/second.png\"" "$hidden_global_state"

empty_cycle_state="$test_dir/state-empty-cycle/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$empty_cycle_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/empty-library" >"$empty_cycle_state"
run_case empty-cycle
grep -qF "WALLPAPER_RESULT empty-cycle next= prev= current=$test_dir/images/first.png" "$test_dir/empty-cycle.log"
[[ "$(grep -cF "Wallpaper: cannot cycle an empty library: $test_dir/empty-library" "$test_dir/empty-cycle.log")" -eq 2 ]]

noop_cycle_state="$test_dir/state-noop-cycle/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$noop_cycle_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/one-library/only.png" "$test_dir/one-library" >"$noop_cycle_state"
touch -d '2001-01-01 00:00:00 UTC' "$noop_cycle_state"
run_case noop-cycle
grep -qF "WALLPAPER_RESULT noop-cycle next= prev= current=$test_dir/one-library/only.png" "$test_dir/noop-cycle.log"
[[ "$(stat -c %Y "$noop_cycle_state")" -eq 978307200 ]]

library_state="$test_dir/state-library/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$library_state")"
printf '{"wallpaper":"","monitorWallpapers":{},"library":"%s"}\n' "$test_dir/library" >"$library_state"
run_case library
grep -qF "WALLPAPER_LIBRARY initial=a.jpg,b.BMP,m.jpeg,z.PNG" "$test_dir/library.log"
grep -qF "WALLPAPER_RESULT library=a.jpg,b.BMP,c.png,m.jpeg,z.PNG" "$test_dir/library.log"

palette_global_state="$test_dir/state-palette-global/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$palette_global_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$palette_global_state"
run_case palette-global
grep -qF "WALLPAPER_RESULT palette-global current=$test_dir/images/second.png events=START $test_dir/images/second.png,END $test_dir/images/second.png" "$test_dir/palette-global.log"

palette_same_state="$test_dir/state-palette-same-path/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$palette_same_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$palette_same_state"
run_case palette-same-path
grep -qF "WALLPAPER_RESULT palette-same-path current=$test_dir/images/first.png events=START $test_dir/images/first.png,END $test_dir/images/first.png" "$test_dir/palette-same-path.log"

palette_override_state="$test_dir/state-palette-override/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$palette_override_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$palette_override_state"
run_case palette-override
grep -qF "WALLPAPER_RESULT palette-override current=$test_dir/images/first.png events=" "$test_dir/palette-override.log"
[[ ! -e "$test_dir/palette-override-colors.log" ]]

palette_latest_state="$test_dir/state-palette-latest/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$palette_latest_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$palette_latest_state"
run_case palette-latest
grep -qF "WALLPAPER_RESULT palette-latest current=$test_dir/images/third.png events=START $test_dir/images/second.png,END $test_dir/images/second.png,START $test_dir/images/third.png,END $test_dir/images/third.png" "$test_dir/palette-latest.log"
if grep -qF "OVERLAP" "$test_dir/palette-latest-colors.log"; then
    echo "Palette commands overlapped"
    exit 1
fi

palette_failure_state="$test_dir/state-palette-failure/quickshell/user/wallpaper.json"
mkdir -p "$(dirname "$palette_failure_state")"
printf '{"wallpaper":"%s","monitorWallpapers":{},"library":"%s"}\n' \
    "$test_dir/images/first.png" "$test_dir/library" >"$palette_failure_state"
run_case palette-failure
grep -qF "WALLPAPER_RESULT palette-failure current=$test_dir/images/second.png" "$test_dir/palette-failure.log"
grep -qF "Wallpaper: palette generation failed: fake palette failure for $test_dir/images/second.png" "$test_dir/palette-failure.log"
grep -qF "Wallpaper set|Colours unchanged|-u|critical|-a|Shell" "$test_dir/palette-failure-notifications.log"

echo "Wallpaper state, validation, live library, and palette behavior passed"
