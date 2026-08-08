#!/usr/bin/env bash

# The control center's bottom container is as tall as the panel showing in it. That replaced a
# rule where every panel was handed the same leftover space, and the difference is invisible in
# source: both versions lay out, and both look plausible in a screenshot of any single panel.
# So this renders the real content and measures the container as the panel changes.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/control-center-panel-sizing"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config"

ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/modules" "$test_dir/config/modules"
ln -s "$repo_root/services" "$test_dir/config/services"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

log="$test_dir/quickshell.log"

# Runs against the ambient Wayland session rather than the offscreen platform: the card holds
# the idle inhibitor, whose service raises a layer surface, and that needs a real compositor to
# raise it on. In CI this runs inside the headless sway session smoke.yml already starts.
#
# Timed out rather than left to run: a measurement that throws never reaches Qt.quit(), and a
# shell with nothing left to do will happily sit there forever.
if ! timeout 30 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
    cat "$log"
    echo "The control center did not load"
    exit 1
fi

# Nested layouts that size each other are exactly what this change introduced, and Qt reports
# that as a warning while still drawing something plausible.
if grep -q "Qt Quick Layouts: Detected recursive rearrange" "$log"; then
    cat "$log"
    echo "The control center triggered a recursive layout rearrange"
    exit 1
fi

# The IPC socket is not one of ours: quickshell fails to bind it when the runtime path is long.
# There is no session bus here, so the network and Bluetooth services warn; that is the service
# behaving, not a defect.
if grep -v 'quickshell\.ipc' "$log" | grep -qE 'TypeError|ReferenceError|Unable to assign|binding loop'; then
    cat "$log"
    echo "The control center loaded with errors"
    exit 1
fi

if ! results="$(grep -o 'CC .*\|OPEN .*' "$log")"; then
    cat "$log"
    echo "The control center never finished constructing"
    exit 1
fi

if grep -q '^CC stuck' <<<"$results"; then
    echo "$results"
    echo "A panel's height never stopped changing"
    exit 1
fi

field() {
    grep -o "^CC $1 .*" <<<"$results" | grep -o " $2=[0-9-]*" | cut -d= -f2 | tr -d ' '
}

# The slot is what the panel asked for, in every state. This is the whole contract: under the
# old rule `slot` was the leftover space and `asked` was ignored.
for state in notifications wifi bluetooth closed; do
    slot="$(field "$state" slot)"
    asked="$(field "$state" asked)"
    if [[ -z "$slot" || -z "$asked" ]]; then
        echo "$results"
        echo "The control center never reported state: $state"
        exit 1
    fi
    if [[ "$slot" != "$asked" ]]; then
        echo "$results"
        echo "The container did not take the panel's height in $state: slot=$slot asked=$asked"
        exit 1
    fi
done

# An empty notification list must claim no height at all — otherwise it holds the bottom edge
# down and, because the window's input mask is cut from this item, silently eats clicks on the
# desktop behind it. Conditional because whether the session is holding notifications is not
# something this test controls: in CI it is empty, on a running desktop it usually is not.
for state in notifications closed; do
    if [[ "$(field "$state" notifications)" == 0 && "$(field "$state" slot)" != 0 ]]; then
        echo "$results"
        echo "An empty notification list still claimed height in $state: $(field "$state" slot)"
        exit 1
    fi
done

# Both detail panels are fixed at everything the card leaves, whatever their lists happen to
# hold. Sizing those to their content was tried and rejected: a scan is live, so the panel
# would resize under the pointer as access points came and went.
for state in wifi bluetooth; do
    if [[ "$(field "$state" slot)" != "$(field "$state" max)" ]]; then
        echo "$results"
        echo "The $state panel is not fixed at the space the card leaves:" \
            "slot=$(field "$state" slot) max=$(field "$state" max)"
        exit 1
    fi
done

distinct() {
    local key="$1" state
    for state in notifications wifi bluetooth closed; do
        field "$state" "$key"
    done | sort -u | wc -l
}

# The card holds its size and its position, and the container's top edge stays put with it, so
# a panel only ever grows downward and the gap between the two never changes. A card that
# shrank to make room, or a container that grew upward into it, both fail here.
for key in cardy card top; do
    if [[ "$(distinct "$key")" != 1 ]]; then
        echo "$results"
        echo "The control center's $key moved between panels"
        exit 1
    fi
done

# Opening the control center must not animate the panel into place. The container starts from
# a Loader with no item, so without a guard the panel unrolls from zero every time it appears —
# which reads as a flicker, not as a resize.
read -r opened settled < <(grep -o '^OPEN got=[0-9-]* asked=[0-9-]*' <<<"$results" | sed 's/OPEN got=//; s/ asked=/ /')
if [[ -z "$opened" || "$opened" != "$settled" ]]; then
    echo "$results"
    echo "The panel animated into place on open: first frame got=$opened asked=$settled"
    exit 1
fi

# And the bottom edge did move, or none of the above proved anything.
if [[ "$(distinct slot)" == 1 ]]; then
    echo "$results"
    echo "Every panel got the same height, so nothing above was exercised"
    exit 1
fi

echo "The control center grows downward from a fixed card"
