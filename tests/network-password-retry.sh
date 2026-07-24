#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/network-password-retry"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/config/services" "$test_dir/bin"

ln -s "$repo_root/services/Network.qml" "$test_dir/config/services/Network.qml"
ln -s "$repo_root/services/NetworkParse.js" "$test_dir/config/services/NetworkParse.js"
ln -s "$repo_root/services/WifiAccessPoint.qml" "$test_dir/config/services/WifiAccessPoint.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"
ln -s "$fixture_dir/nmcli" "$test_dir/bin/nmcli"

export PATH="$test_dir/bin:/usr/bin"
export WAYLAND_DISPLAY=
export QT_QPA_PLATFORM=offscreen

run_case() {
    local name="$1"
    local retry_exit_code="$2"
    local expected_asking="$3"
    local case_dir="$test_dir/$name"

    mkdir -p "$case_dir/runtime"
    chmod 700 "$case_dir/runtime"
    export NETWORK_PASSWORD_RETRY_STATE="$case_dir/connection-attempts"
    export NETWORK_PASSWORD_RETRY_EXIT_CODE="$retry_exit_code"
    export XDG_RUNTIME_DIR="$case_dir/runtime"

    if ! qs --no-color -p "$test_dir/config" >"$case_dir/quickshell.log" 2>&1; then
        cat "$case_dir/quickshell.log"
        exit 1
    fi

    if [[ ! -f "$NETWORK_PASSWORD_RETRY_STATE" ]] || [[ "$(<"$NETWORK_PASSWORD_RETRY_STATE")" != 2 ]]; then
        cat "$case_dir/quickshell.log"
        echo "Expected the Wi-Fi connection to be attempted twice"
        exit 1
    fi

    if ! grep -q "PASSWORD_RETRY_ASKING=$expected_asking" "$case_dir/quickshell.log"; then
        cat "$case_dir/quickshell.log"
        echo "The password retry did not update the access point state"
        exit 1
    fi

    if grep -q "TypeError: Value is null and could not be converted to an object" "$case_dir/quickshell.log"; then
        cat "$case_dir/quickshell.log"
        echo "The password retry dereferenced a null Wi-Fi target"
        exit 1
    fi
}

run_case success 0 false
run_case failure 10 true
