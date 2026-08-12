#!/usr/bin/env bash

# The tooltip's contract is a set of Material 3 metrics that only exist once real text has
# been laid out: the plain chip's 24px floor and 200px ceiling, the rich card's 320px ceiling,
# and the padding around both. None of that is visible in the source, so this builds the
# containers offscreen and measures them, then places two in-scene tooltips — one with room on
# the side it asked for, one against the window edge that has to flip.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/tooltip-geometry"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/modules/common/widgets"

# An `import qs.<dir>` compiles every file in that directory, so the tree holds the tooltip and
# what it imports and nothing else. CliphistImage is the one widget that reaches into
# qs.services, which would drag the whole service layer into a geometry measurement.
ln -s "$repo_root/modules/common/Appearance.qml" "$test_dir/config/modules/common/Appearance.qml"
ln -s "$repo_root/modules/common/TooltipManager.qml" "$test_dir/config/modules/common/TooltipManager.qml"
ln -s "$repo_root/modules/common/functions" "$test_dir/config/modules/common/functions"
for file in "$repo_root"/modules/common/widgets/*; do
    name="$(basename "$file")"
    [[ "$name" == CliphistImage.qml ]] && continue
    ln -s "$file" "$test_dir/config/modules/common/widgets/$name"
done
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

runtime_dir="$test_dir/runtime"
mkdir -p "$runtime_dir"
chmod 700 "$runtime_dir"
log="$test_dir/tooltip.log"

# Timed out rather than left to run: a measurement that throws never reaches Qt.quit(), and an
# offscreen shell with nothing to draw to will happily sit there forever.
if ! QT_QPA_PLATFORM=offscreen \
    WAYLAND_DISPLAY= \
    XDG_RUNTIME_DIR="$runtime_dir" \
    timeout 20 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
    cat "$log"
    echo "The tooltip did not load"
    exit 1
fi

# A binding that throws still leaves the object standing and the measurement still logs, so a
# broken size binding would look like a tooltip that simply drew nothing. The IPC socket is not
# ours: quickshell fails to bind it when the runtime path is long.
if grep -v 'quickshell\.ipc' "$log" | grep -qE 'ERROR|TypeError|ReferenceError|Unable to assign'; then
    cat "$log"
    echo "The tooltip loaded with errors"
    exit 1
fi

if ! results="$(grep -o 'PLAIN .*\|WRAPPED .*\|RICH .*\|RICHBODY .*\|CUSTOM .*\|SCENE .*' "$log")"; then
    cat "$log"
    echo "The tooltip never finished measuring"
    exit 1
fi

field() { grep -o "$1" <<<"$results" | head -1 | cut -d= -f2; }
dimension() { grep "^$1 " <<<"$results" | head -1 | awk '{print $2}'; }

fail() {
    echo "$results"
    echo "$1"
    exit 1
}

plain_w="$(dimension PLAIN | cut -dx -f1)"
plain_h="$(dimension PLAIN | cut -dx -f2)"
wrapped_w="$(dimension WRAPPED | cut -dx -f1)"
wrapped_h="$(dimension WRAPPED | cut -dx -f2)"
rich_w="$(dimension RICH | cut -dx -f1)"
richbody_h="$(dimension RICHBODY | cut -dx -f2)"

# M3 plain tooltip: min height 24, min width 40, max width 200. A single short line has to sit
# on the floor exactly — 12px text on a 16px fixed line box plus 4px above and below.
((plain_h == 24)) || fail "The plain tooltip is not on M3's 24px floor: height=$plain_h"
((plain_w >= 40)) || fail "The plain tooltip is under M3's 40px minimum width: width=$plain_w"
((plain_w <= 200)) || fail "The plain tooltip is over M3's 200px maximum width: width=$plain_w"

# The long tray description has to wrap rather than widen, and wrapping is the only way it can
# be taller than one line.
((wrapped_w <= 200)) || fail "A long plain tooltip did not wrap at 200px: width=$wrapped_w"
((wrapped_h > 24)) || fail "A long plain tooltip did not wrap onto more than one line: height=$wrapped_h"

# M3 rich tooltip: max width 320. The subhead is deliberately longer than that.
((rich_w <= 320)) || fail "The rich tooltip is over M3's 320px maximum width: width=$rich_w"
((rich_w > 200)) || fail "The rich tooltip did not use the width its subhead needs: width=$rich_w"

# Rich vertical padding is 12 above and 8 below a 20px line box, so a subheadless rich tooltip
# is exactly 40. This is what catches the subhead's Text still taking a layout slot when empty.
((richbody_h == 40)) || fail "A rich tooltip with no subhead is not 12+20+8 tall: height=$richbody_h"

# Custom content gets the same rich padding as the two-string variant and nothing else: three
# 18px rows at 10px spacing is 74, plus 12 above and 8 below; 120 wide plus 16 either side.
custom_w="$(dimension CUSTOM | cut -dx -f1)"
custom_h="$(dimension CUSTOM | cut -dx -f2)"
((custom_w == 152)) || fail "Custom tooltip content is not padded 16px either side: width=$custom_w"
((custom_h == 94)) || fail "Custom tooltip content is not padded 12 above and 8 below: height=$custom_h"

# Shadow margin is what a host has to leave around the card. Plain has no elevation token in
# M3 at all, so it must ask for no room; rich must ask for some.
[[ "$(field 'PLAIN .*shadow=[0-9]*')" == 0 ]] || fail "The plain tooltip reserved shadow room it does not need"
[[ "$(field 'RICH .*shadow=[0-9]*')" != 0 ]] || fail "The rich tooltip reserved no room for its elevation"

# Placement, in the anchor's own coordinates. An 80px anchor with a narrower tooltip centres it
# at a positive offset; the tooltip sits its 4px gap above, so its bottom edge is at -4.
centred="$(field 'centred=[0-9-]*,[0-9-]*')"
centred_y="${centred#*,}"
centred_h="$(grep -o 'centred=[^ ]* [0-9]*x[0-9]*' <<<"$results" | awk '{print $2}' | cut -dx -f2)"
(((centred_y + centred_h) == -4)) || fail "The in-scene tooltip is not 4px above its anchor: y=$centred_y height=$centred_h"

# Against the top of the window there is no room above, so it has to flip below the anchor:
# 30px of anchor plus the 4px gap.
flipped="$(field 'flipped=[0-9-]*,[0-9-]*')"
flipped_y="${flipped#*,}"
((flipped_y == 34)) || fail "The in-scene tooltip did not flip below an anchor at the window's top edge: y=$flipped_y"

echo "The tooltip holds M3's plain and rich metrics and places itself against the window edge"
