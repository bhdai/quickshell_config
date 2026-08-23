#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/system-sleep"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/config/services" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"
ln -s "$repo_root/services/SystemSleep.qml" "$test_dir/config/services/SystemSleep.qml"
ln -s "$repo_root/services/SystemSleepParse.js" "$test_dir/config/services/SystemSleepParse.js"
ln -s "$repo_root/services/Time.qml" "$test_dir/config/services/Time.qml"
ln -s "$fixture_dir/shell.qml" "$test_dir/config/shell.qml"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "signal sender=:1.0 interface=org.freedesktop.login1.Manager; member=PrepareForSleep\n"' \
    'printf "   boolean false\n"' \
    >"$test_dir/bin/dbus-monitor"
chmod +x "$test_dir/bin/dbus-monitor"

PATH="$test_dir/bin:$PATH" \
QT_QPA_PLATFORM=offscreen \
WAYLAND_DISPLAY= \
XDG_RUNTIME_DIR="$test_dir/runtime" \
    qs --no-color -p "$test_dir/config" >"$test_dir/quickshell.log" 2>&1

if ! grep -qF "SYSTEM_SLEEP resumed" "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "The sleep service did not report resume"
    exit 1
fi

if grep -qF "SYSTEM_SLEEP timeout" "$test_dir/quickshell.log"; then
    cat "$test_dir/quickshell.log"
    echo "The sleep service timed out before reporting resume"
    exit 1
fi

echo "The sleep service reports logind resume events"
