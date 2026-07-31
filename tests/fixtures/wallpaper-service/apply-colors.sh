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

printf 'END %s\n' "$1" >>"$log"
