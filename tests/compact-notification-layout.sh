#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/compact-notification-layout"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config"

ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/modules" "$test_dir/config/modules"
ln -s "$repo_root/services" "$test_dir/config/services"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! qs --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    exit 1
fi

if grep -q "Qt Quick Layouts: Detected recursive rearrange" "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "Compact notifications triggered a recursive layout rearrange"
    exit 1
fi
