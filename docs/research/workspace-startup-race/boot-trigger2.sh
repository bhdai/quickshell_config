#!/usr/bin/env bash
# Deterministic reproducer for the startup snapshot race.
#
# A nested Hyprland starts the real shell plus N stand-in apps that map early, so
# their windows exist before the shell is ready. The harness then tails the shell's
# log and, the instant the shell issues its startup "j/workspaces" request, moves
# those windows onto fresh workspaces. Moving an existing window creates a workspace
# in ~5ms, which lands inside the interval between Hyprland generating that reply and
# the shell parsing it — the window in which an event-created workspace is deleted by
# a reply that predates it.
#
#   ./boot-trigger2.sh <outdir> <n-apps>
set -uo pipefail

JOB=/home/dai/.claude/jobs/e2a0bfe0/tmp
OUT=$1
APPS=${2:-4}

SHELL_PATH=${SHELL_PATH:-$JOB/realshell}
PROBE_LIFETIME=${PROBE_LIFETIME:-20000}
PROBE_RECOVER=${PROBE_RECOVER:-13000}

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
    echo "exec-once = sh -c 'PROBE_LIFETIME=$PROBE_LIFETIME PROBE_RECOVER=$PROBE_RECOVER XDG_STATE_HOME=$OUT/state exec qs -p $SHELL_PATH --log-times --log-rules \"quickshell.hyprland*=true\" > $OUT/probe.log 2>&1'"
    for i in $(seq 1 "$APPS"); do
        echo "exec-once = [workspace $i silent] sh -c 'FAKEAPP_DELAY=150 exec qs -p $JOB/fakeapp > $OUT/app$i.log 2>&1'"
    done
} > "$CONF"

env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    Hyprland -c "$CONF" > "$OUT/compositor.log" 2>&1 &
HYPR_PID=$!

cleanup() {
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
    sleep 0.1
done
[[ -z "$SIG" ]] && { echo "FAIL: nested Hyprland did not come up" >&2; exit 1; }
echo "nested sig $SIG (pid $HYPR_PID)" > "$OUT/meta.txt"

# Collect the window addresses up front so the trigger itself is one cheap call.
addrs=()
for _ in $(seq 1 100); do
    mapfile -t addrs < <(hyprctl -i "$SIG" clients -j | grep -oP '"address":\s*"\K[^"]+')
    [[ ${#addrs[@]} -ge $APPS ]] && break
    sleep 0.05
done

batch=""
i=10
for a in "${addrs[@]}"; do
    i=$((i + 1))
    [[ -n $batch ]] && batch+=";"
    batch+="dispatch movetoworkspacesilent $i,address:$a"
done
echo "trigger batch: $batch" >> "$OUT/meta.txt"

python3 "$JOB/trigger.py" "$SIG" "$OUT/probe.log" 'Making request: "j/workspaces"' "$batch" \
    > "$OUT/trigger.log" 2>&1 &

model_ids() {
    sed 's/\x1b\[[0-9;]*m//g' "$OUT/probe.log" | grep -oP 'PROBE \+\d+ms (change|heartbeat) \Kws=\[[^]]*' |
        tail -1 | sed 's/ws=\[//' | tr ',' '\n' | sort -n -u
}
truth_ids() {
    hyprctl -i "$SIG" workspaces -j | grep -oP '"id":\s*\K-?\d+' | sort -n -u
}

sleep 8
{
    echo "--- state at $(date +%T.%3N)"
    echo "model:  $(model_ids | tr '\n' ' ')"
    echo "truth:  $(truth_ids | tr '\n' ' ')"
} >> "$OUT/meta.txt" 2>&1

# Switching to a workspace the model lost is the user's own recovery attempt.
missing=$(comm -23 <(truth_ids) <(model_ids) | head -1)
{
    if [[ -n $missing ]]; then
        echo "--- switching to missing workspace $missing"
        hyprctl -i "$SIG" dispatch workspace "$missing"
        sleep 1.5
        echo "model after switch: $(model_ids | tr '\n' ' ')"
    else
        echo "--- nothing missing to switch to"
    fi
} >> "$OUT/meta.txt" 2>&1

# The shell's own QML-side repair attempt runs at PROBE_RECOVER; then the external one.
sleep 5
{
    echo "--- hyprctl reload $(date +%T.%3N)"
    hyprctl -i "$SIG" reload
    sleep 2
    echo "model after reload: $(model_ids | tr '\n' ' ')"
    echo "truth after reload: $(truth_ids | tr '\n' ' ')"
} >> "$OUT/meta.txt" 2>&1

for _ in $(seq 1 60); do
    pgrep -f "qs -p $SHELL_PATH" >/dev/null || break
    sleep 0.5
done
