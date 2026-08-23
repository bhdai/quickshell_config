#!/usr/bin/env bash

# A collapsed notification group must build three preview rows, not one per notification it
# holds. The expanded list sits beside the previews in the same layout, and a Repeater builds
# its delegates whether or not the item holding them is visible — so every open of the control
# center paid for every notification the store had ever kept, all of them invisible.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/notification-group-collapsed"
test_dir="$(mktemp -d)"
qs_bin="$(command -v qs)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config"

ln -s "$repo_root/assets" "$test_dir/config/assets"
ln -s "$repo_root/modules" "$test_dir/config/modules"
ln -s "$repo_root/services" "$test_dir/config/services"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

log="$test_dir/quickshell.log"

if ! timeout 30 "$qs_bin" --no-color -p "$test_dir/config" >"$log" 2>&1; then
    cat "$log"
    echo "The notification group did not load"
    exit 1
fi

count() {
    grep -o "^ *DEBUG qml: ROWS $1=[0-9]*" "$log" | grep -o '[0-9]*$'
}

stored="$(grep -o 'stored=[0-9]*' "$log" | head -1 | cut -d= -f2)"
collapsed="$(count collapsed)"
expanded="$(count expanded)"

if [[ -z "$stored" || -z "$collapsed" || -z "$expanded" ]]; then
    cat "$log"
    echo "The notification group never reported its row count"
    exit 1
fi

# Three previews plus the single-notification row the group keeps for when it drops to one.
if ((collapsed > 4)); then
    cat "$log"
    echo "A collapsed group of $stored built $collapsed rows; it may build at most 4"
    exit 1
fi

# And expanding still shows all of them, or the previous check passes by showing nothing.
if ((expanded < stored)); then
    cat "$log"
    echo "An expanded group of $stored built only $expanded rows"
    exit 1
fi

echo "A collapsed notification group builds $collapsed rows and expands to $expanded"
