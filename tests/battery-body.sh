#!/usr/bin/env bash

# The state → glyph rule is unit-tested; this checks it is actually wired to what gets drawn,
# and that the trailing glyph stays an overhang rather than widening the body it hangs off.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/battery-body"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"

ln -s "$repo_root/modules" "$test_dir/config/modules"
ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/services/battery_glyph.js" "$test_dir/config/services/battery_glyph.js"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

if ! DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_dir/no-system-bus" \
    QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    "$qs_bin" --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1; then
    cat "$test_dir/quickshell.log"
    echo "The battery body did not build"
    exit 1
fi

if ! results="$(grep -o 'BATTERY_BODY .*' "$test_dir/quickshell.log")"; then
    cat "$test_dir/quickshell.log"
    echo "The battery body never finished constructing"
    exit 1
fi

expect_glyph() {
    local name="$1" want="$2" line
    line="$(grep "name=$name " <<<"$results")" || {
        echo "no result for $name"
        exit 1
    }
    if [[ "$line" != *"glyph=$want"* ]]; then
        echo "$name should draw $want: $line"
        exit 1
    fi
}

# The bolt means current is moving, and nothing else does.
expect_glyph discharging nob
expect_glyph charging bolt
expect_glyph held nob
expect_glyph full nob

fill_of() {
    sed -n "s/.*name=$1 .*fill=\([^ ]*\).*/\1/p" <<<"$results"
}

# With the glyph out of it, the fill is the only thing left saying whether the cable is in. The
# charge threshold makes "plugged in, no current" the common state, so it must read as on-power
# and not as running down.
if [[ "$(fill_of held)" != "$(fill_of charging)" ]]; then
    echo "held did not take the charging fill:"
    echo "$results"
    exit 1
fi

if [[ "$(fill_of held)" == "$(fill_of discharging)" ]]; then
    echo "held is indistinguishable from running on battery:"
    echo "$results"
    exit 1
fi

# Every state measures the same: the glyph overhangs the body, so it must not add width, or the
# bar would reflow each time the cable moves.
widths="$(sed -n 's/.*width=\([0-9]*\).*/\1/p' <<<"$results" | sort -u | wc -l)"
if [[ "$widths" -ne 1 ]]; then
    echo "the glyph changed the body's width across states:"
    echo "$results"
    exit 1
fi

if [[ "$(sed -n 's/.*width=\([0-9]*\).*/\1/p' <<<"$results" | head -1)" -le 0 ]]; then
    echo "the body took no width:"
    echo "$results"
    exit 1
fi
