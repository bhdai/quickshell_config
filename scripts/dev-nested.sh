#!/usr/bin/env bash
#
# dev-nested.sh — Run the dev clone inside a nested Hyprland.
#
# ext-session-lock-v1 binds a session lock to the compositor that granted it, so a
# WlSessionLock raised in here covers this nested instance's own window and cannot
# reach the desktop. That is what makes lock-screen work safe to iterate on: a wedged
# nested compositor is killed, not recovered from a TTY.
#
# Kill it with Ctrl-C here, or `pkill -f qs-dev-nested` from anywhere. Closing the
# nested window does *not* work: Hyprland's Wayland backend never acts on the
# xdg_toplevel close request its own window receives, locked or not. Neither escape
# needs the nested compositor to be responsive, which is the point.
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
NESTED_STATE="$WORK/state"
mkdir -p "$NESTED_STATE"

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
# of inheriting the host's, which is what makes the two instances addressable apart.
env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$HOST_DISPLAY" \
    Hyprland -c "$WORK/hypr.conf" > "$WORK/compositor.log" 2>&1 &
HYPR_PID=$!

# The nested compositor mints both its wayland-N socket name and its instance
# signature at startup, so neither can be passed in — both have to be read back out
# of `hyprctl instances`, which lists every instance regardless of the signature in
# the environment. Matching on the pid we just forked is what makes this unambiguous
# when more than one nested compositor is up.
NESTED=
NESTED_SIG=
for _ in $(seq 1 40); do
    read -r NESTED NESTED_SIG < <(hyprctl instances 2>/dev/null | awk -v pid="$HYPR_PID" '
        $1 == "instance" { sig = substr($2, 1, length($2) - 1) }
        $1 == "pid:"     { mine = ($2 == pid) }
        $1 == "wl" && mine { print $3, sig; exit }')
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
echo "running $CONFIG — edits hot-reload as usual"
echo "Ctrl-C to stop, or \`pkill -f qs-dev-nested\` — the nested window ignores close"

# HYPRLAND_INSTANCE_SIGNATURE has to be overridden here too, not just unset for the
# compositor: qs would otherwise inherit the *host's* signature, and every
# Quickshell.Hyprland query and dispatch from inside the nested shell would land on
# the real desktop instead of the one it is running in.
env WAYLAND_DISPLAY="$NESTED" HYPRLAND_INSTANCE_SIGNATURE="$NESTED_SIG" \
    XDG_STATE_HOME="$NESTED_STATE" qs -p "$CONFIG"
