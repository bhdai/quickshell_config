#!/usr/bin/env bash
# One simulated cold start: a nested Hyprland whose exec-once launches the observed
# shell and then N stand-in apps pinned to workspaces, mirroring
# dotfiles/config/hypr/autostart.lua. Each app maps its window after its own delay,
# so a boot samples N workspace-creation instants against one startup snapshot.
#
#   ./boot.sh <outdir> <delay-ms>...
#
# SHELL_PATH   config to observe (default: the headless probe)
# PROBE_SLEEP  seconds to hold the shell back — stands in for QML load time when the
#              observed shell is the lightweight probe rather than the real config
# PROBE_LIFETIME  ms before the probe calls Qt.quit()
set -uo pipefail

JOB=/home/dai/.claude/jobs/e2a0bfe0/tmp
OUT=$1
shift
DELAYS=("$@")

SHELL_PATH=${SHELL_PATH:-$JOB/probe}
PROBE_LIFETIME=${PROBE_LIFETIME:-10000}
PROBE_SLEEP=${PROBE_SLEEP:-0}

mkdir -p "$OUT/state"
CONF="$OUT/hypr.conf"

{
    cat <<'EOF'
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
    # Shell first, then the pinned apps — the order autostart.lua uses. XDG_STATE_HOME
    # is redirected so a real-config run cannot write to the live session's state.
    echo "exec-once = sh -c 'sleep $PROBE_SLEEP; PROBE_LIFETIME=$PROBE_LIFETIME XDG_STATE_HOME=$OUT/state exec qs -p $SHELL_PATH --log-times --log-rules \"quickshell.hyprland*=true\" > $OUT/probe.log 2>&1'"
    i=0
    for d in "${DELAYS[@]}"; do
        i=$((i + 1))
        echo "exec-once = [workspace $i silent] sh -c 'FAKEAPP_DELAY=$d exec qs -p $JOB/fakeapp --log-times > $OUT/app$i.log 2>&1'"
    done
} > "$CONF"

# CPU contention stands in for a real session start, where the shell competes with
# every other exec-once for the machine. It stretches the interval between the shell
# issuing its startup requests and getting round to parsing the replies.
LOAD=${LOAD:-0}
LOAD_PIDS=()
for _ in $(seq 1 "$LOAD"); do
    (while :; do :; done) &
    LOAD_PIDS+=($!)
done

env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    Hyprland -c "$CONF" > "$OUT/compositor.log" 2>&1 &
HYPR_PID=$!

cleanup() {
    [[ ${#LOAD_PIDS[@]} -gt 0 ]] && kill "${LOAD_PIDS[@]}" 2>/dev/null
    kill "$HYPR_PID" 2>/dev/null
    sleep 0.3
    kill -9 "$HYPR_PID" 2>/dev/null
}
trap cleanup EXIT

SIG=
for _ in $(seq 1 60); do
    SIG=$(hyprctl instances 2>/dev/null | awk -v pid="$HYPR_PID" '
        $1 == "instance" { sig = substr($2, 1, length($2) - 1) }
        $1 == "pid:" && $2 == pid { print sig; exit }')
    [[ -n "$SIG" ]] && break
    sleep 0.2
done

if [[ -z "$SIG" ]]; then
    echo "FAIL: nested Hyprland did not come up" >&2
    exit 1
fi
echo "nested sig $SIG (pid $HYPR_PID)" > "$OUT/meta.txt"

sleep 4
[[ ${#LOAD_PIDS[@]} -gt 0 ]] && kill "${LOAD_PIDS[@]}" 2>/dev/null
LOAD_PIDS=()

sleep 2
# Recovery probe: does an external workspace switch repair a model that came up wrong?
{
    echo "--- dispatch round trip"
    hyprctl -i "$SIG" dispatch workspace 9
    sleep 0.7
    hyprctl -i "$SIG" dispatch workspace 1
    sleep 0.7
} >> "$OUT/meta.txt" 2>&1

sleep 1
{
    echo "--- truth $(date +%T.%3N)"
    echo "workspaces: $(hyprctl -i "$SIG" workspaces -j | grep -oP '"id":\s*\K-?\d+' | sort -n | tr '\n' ',')"
    echo "activeWorkspace: $(hyprctl -i "$SIG" monitors -j | grep -A2 '"activeWorkspace"' | grep -oP '"id":\s*\K-?\d+' | head -1)"
} >> "$OUT/meta.txt" 2>&1

# The shell tries to repair itself from QML at PROBE_RECOVER (~t+10s). Only after
# that does the external primitive get its turn: configreloaded is the one event path
# that re-runs a full snapshot with canCreate set.
if [[ ${TEST_RELOAD:-1} == 1 ]]; then
    sleep 5
    echo "--- hyprctl reload $(date +%T.%3N)" >> "$OUT/meta.txt"
    hyprctl -i "$SIG" reload >> "$OUT/meta.txt" 2>&1
    sleep 2
fi

for _ in $(seq 1 60); do
    pgrep -f "qs -p $SHELL_PATH" >/dev/null || break
    sleep 0.5
done
