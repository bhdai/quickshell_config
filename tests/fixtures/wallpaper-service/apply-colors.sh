#!/usr/bin/env bash

set -euo pipefail

log="${WALLPAPER_TEST_COLOR_LOG:?}"
lock="$log.lock"

if ! mkdir "$lock" 2>/dev/null; then
    printf 'OVERLAP %s\n' "$1" >>"$log"
    exit 99
fi
trap 'rmdir "$lock"' EXIT

printf 'START %s\n' "$1" >>"$log"
sleep "${WALLPAPER_TEST_COLOR_DELAY:-0.05}"

if [[ "${WALLPAPER_TEST_COLOR_FAIL:-}" == "$1" ]]; then
    printf 'FAIL %s\n' "$1" >>"$log"
    printf 'fake palette failure for %s\n' "$1" >&2
    exit 7
fi

palette_dir="${XDG_STATE_HOME:?}/quickshell/user/generated"
mkdir -p "$palette_dir"
case "$1" in
    *second.png) primary="#123456" ;;
    *third.png) primary="#654321" ;;
    *) primary="#abcdef" ;;
esac
printf '{"primary":"%s"}\n' "$primary" >"$palette_dir/colors.json.next"
mv "$palette_dir/colors.json.next" "$palette_dir/colors.json"
printf 'END %s\n' "$1" >>"$log"
