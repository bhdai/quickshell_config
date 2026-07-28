#!/usr/bin/env bash
#
# dev-nested.sh — Run the dev clone inside a nested Hyprland.
#
# ext-session-lock-v1 binds a session lock to the compositor that granted it, so a
# WlSessionLock raised in here covers this nested instance's own window and cannot
# reach the desktop. That is what makes lock-screen work safe to iterate on: a wedged
# nested compositor is closed, not recovered from a TTY.
#
#   ./scripts/dev-nested.sh              # run the dev clone this script lives in
#   ./scripts/dev-nested.sh <path>       # run some other config directory
#
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG=${1:-$HERE}

: "${WAYLAND_DISPLAY:?must be run from inside a Wayland session}"
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

HOST_DISPLAY=$WAYLAND_DISPLAY
WORK=$(mktemp -d /tmp/qs-dev-nested.XXXXXX)

# disable_autoreload keeps Hyprland's own config watcher from adding a second reload
# path on top of Quickshell's, which matters when what you are testing *is* reload
# behaviour. The rest is only to keep the nested instance cheap and quiet.
cat > "$WORK/hypr.conf" <<'EOF'
monitor=,1280x800@60,0x0,1
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
    disable_autoreload = true
}
animations { enabled = false }
decoration { blur { enabled = false } shadow { enabled = false } }
EOF

cleanup() {
    pkill -f "Hyprland -c $WORK/hypr.conf" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

# HYPRLAND_INSTANCE_SIGNATURE is unset so the nested compositor mints its own instead
# of inheriting the host's — otherwise hyprctl and Quickshell's Hyprland service both
# talk to the outer session from inside the nested one.
env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$HOST_DISPLAY" \
    Hyprland -c "$WORK/hypr.conf" > "$WORK/compositor.log" 2>&1 &

# The nested compositor mints a fresh wayland-N socket rather than reusing a name we
# could pass in, so it has to be discovered: newest socket that is not the host's.
NESTED=
for _ in $(seq 1 40); do
    NESTED=$(ls -t "$XDG_RUNTIME_DIR" \
        | grep '^wayland-[0-9]*$' \
        | grep -v "^$HOST_DISPLAY\$" \
        | head -1)
    [[ -n "$NESTED" ]] && break
    sleep 0.5
done

if [[ -z "$NESTED" ]]; then
    echo "nested Hyprland did not come up; see $WORK/compositor.log" >&2
    cat "$WORK/compositor.log" >&2
    trap - EXIT
    exit 1
fi
sleep 2

echo "nested compositor on $NESTED (host $HOST_DISPLAY)"
echo "running $CONFIG — edits hot-reload as usual; close the window or Ctrl-C to stop"

env WAYLAND_DISPLAY="$NESTED" qs -p "$CONFIG"
