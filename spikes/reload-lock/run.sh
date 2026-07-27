#!/usr/bin/env bash
#
# Reload-while-locked spike for issue #57. See README.md.
#
# Every run happens inside a *nested* Hyprland, launched as a Wayland client of the
# real session. Its ext-session-lock-v1 lock covers only its own window, so a wrong
# result cannot wedge the desktop — which is why this needs no TTY standby.
#
#   ./run.sh <name> <lockId> <persistLockState> <trigger>
#   ./run.sh all          # the whole matrix
#
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK=${SPIKE_WORK:-/tmp/qs-reload-spike}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

mkdir -p "$WORK/flat" "$WORK/nested" "$WORK/probe"

cat > "$WORK/hypr.conf" <<'EOF'
monitor=,640x400@60,0x0,1
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
    disable_autoreload = true
}
animations { enabled = false }
decoration { blur { enabled = false } shadow { enabled = false } }
EOF

# Restart the nested compositor. A run that ends with a stranded lock leaves the
# compositor refusing every later lock, so each row needs a fresh one.
restart_nested() {
    pkill -f "Hyprland -c $WORK/hypr.conf" 2>/dev/null
    sleep 2
    env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY=wayland-1 \
        Hyprland -c "$WORK/hypr.conf" > "$WORK/nested-compositor.log" 2>&1 &
    local disp=
    for _ in $(seq 1 40); do
        disp=$(ls -t "$XDG_RUNTIME_DIR" | grep '^wayland-[0-9]*$' | grep -v '^wayland-1$' | head -1)
        [[ -n "$disp" ]] && break
        sleep 0.5
    done
    sleep 2
    echo "$disp"
}

# Ask the compositor whether it is still locked, by having a fresh client try to
# lock it. Hyprland refuses a lock held by a dead client (allow_session_lock_restore
# defaults false), so "denied" means stranded and "granted" means genuinely unlocked.
probe() {
    local disp=$1 tag=$2
    local log="$WORK/probe-$tag.log"
    cp "$HERE/shell.qml" "$WORK/probe/shell.qml"
    env WAYLAND_DISPLAY="$disp" qs --no-color -p "$WORK/probe" > "$log" 2>&1 &
    local pid=$!
    sleep 4
    local iid
    iid=$(grep -o 'by-id/[a-z0-9]*' "$log" | head -1 | cut -d/ -f2)
    env WAYLAND_DISPLAY="$disp" qs ipc -i "$iid" call spike lock >/dev/null 2>&1
    sleep 3
    if grep -q 'lock.secure -> true' "$log"; then
        echo "--- verdict:   compositor was UNLOCKED (fresh client acquired the lock)"
        env WAYLAND_DISPLAY="$disp" qs ipc -i "$iid" call spike unlock >/dev/null 2>&1
        sleep 1
    else
        echo "--- verdict:   compositor still LOCKED with no client (fresh lock denied)"
    fi
    kill -9 $pid 2>/dev/null
    wait $pid 2>/dev/null
}

run() {
    local name=$1 lockid=$2 persist=$3 trigger=$4
    local log="$WORK/$name.log" disp dir knob
    disp=$(restart_nested)

    # `nested-*` triggers run against the LockModule.qml shape the real lock/ module
    # will have; the rest run against the flat single-file harness.
    case $trigger in
        nested-*|sibling-above) dir=$WORK/nested
                                cp "$HERE/nested/shell.qml" "$HERE/nested/LockModule.qml" "$dir/"
                                knob=$dir/LockModule.qml ;;
        *)                      dir=$WORK/flat
                                cp "$HERE/shell.qml" "$dir/"
                                knob=$dir/shell.qml ;;
    esac
    python3 "$HERE/edits.py" set-knob "$knob" "lockId: \"spikeLock\"" "lockId: \"$lockid\""
    python3 "$HERE/edits.py" set-knob "$knob" "persistLockState: true" "persistLockState: $persist"

    env WAYLAND_DISPLAY="$disp" qs --no-color -p "$dir" > "$log" 2>&1 &
    local pid=$!
    sleep 4
    local iid
    iid=$(grep -o 'by-id/[a-z0-9]*' "$log" | head -1 | cut -d/ -f2)
    ipc() { env WAYLAND_DISPLAY="$disp" qs ipc -i "$iid" call spike "$@" 2>&1; }

    echo "### $name  lockId=\"$lockid\" persist=$persist trigger=$trigger"
    ipc lock >/dev/null
    sleep 3
    echo "--- locked:    $(ipc status)"

    case $trigger in
        nudge|nested-nudge) python3 "$HERE/edits.py" nudge "$knob" ;;
        syntax-error)  python3 "$HERE/edits.py" syntax-error "$knob" ;;
        rename-id)     python3 "$HERE/edits.py" set-knob "$knob" \
                           "lockId: \"$lockid\"" "lockId: \"${lockid}B\"" ;;
        reorder)       python3 "$HERE/edits.py" reorder "$knob" ;;
        sibling-above) python3 "$HERE/edits.py" sibling-above "$dir/shell.qml" ;;
    esac
    sleep 5

    if kill -0 $pid 2>/dev/null; then
        echo "--- process:   ALIVE"
        echo "--- post:      $(ipc status)"
        # Release a still-held lock, so the probe measures the reload outcome
        # rather than this script's own client death.
        ipc unlock >/dev/null 2>&1
        sleep 2
    else
        echo "--- process:   DEAD (exit $(wait $pid; echo $?))"
    fi
    grep -E 'FATAL|Failed to load|Unexpected token|duplicate_output' "$log" | sed 's/^/      /'
    kill -9 $pid 2>/dev/null
    wait $pid 2>/dev/null
    sleep 1
    probe "$disp" "$name"
    echo
}

if [[ ${1:-} == all ]]; then
    run R1  spikeLock true  nudge
    run R2  spikeLock false nudge
    run R3  spikeLock true  rename-id
    run R4  spikeLock false rename-id
    run R5  spikeLock true  syntax-error
    run R6  ""        true  nudge
    run R7  ""        true  reorder
    run R8  spikeLock true  reorder
    run R9  ""        false reorder
    run R10 spikeLock true  nested-nudge
    run R11 spikeLock true  sibling-above
    run R12 ""        true  sibling-above
    pkill -f "Hyprland -c $WORK/hypr.conf"
else
    run "$@"
    pkill -f "Hyprland -c $WORK/hypr.conf"
fi
