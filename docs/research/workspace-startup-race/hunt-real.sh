#!/usr/bin/env bash
# Aim window maps at the gap between the shell connecting its event socket and the
# shell parsing its startup workspace snapshot — the interval in which an event-created
# workspace can be deleted by a reply that predates it.
#
#   ./hunt-real.sh <n-boots> <n-apps> <centre-ms> <spread-ms> <tag>
set -uo pipefail

JOB=/home/dai/.claude/jobs/e2a0bfe0/tmp
N=${1:-10}
APPS=${2:-10}
CENTRE=${3:-890}
SPREAD=${4:-90}
TAG=${5:-real}

export SHELL_PATH=$JOB/realshell
export PROBE_LIFETIME=${PROBE_LIFETIME:-18000}
export PROBE_RECOVER=${PROBE_RECOVER:-12000}
export LOAD=${LOAD:-0}

for n in $(seq 1 "$N"); do
    OUT="$JOB/runs/$TAG-$(printf %03d "$n")"
    rm -rf "$OUT"

    delays=()
    for _ in $(seq 1 "$APPS"); do
        d=$((CENTRE - SPREAD + RANDOM % (2 * SPREAD + 1)))
        ((d < 0)) && d=0
        delays+=("$d")
    done

    timeout 150 "$JOB/boot.sh" "$OUT" "${delays[@]}" >/dev/null 2>&1

    clean=$(sed 's/\x1b\[[0-9;]*m//g' "$OUT/probe.log" 2>/dev/null)
    pick() { grep -oP "PROBE \+\d+ms $1 \Kws=\[[^]]*\]" <<< "$clean" | tail -1; }

    truth=$(grep -oP '^workspaces: \K.*' "$OUT/meta.txt" 2>/dev/null | sed 's/,$//')
    postSnapshot=$(grep -oP 'PROBE \+\d+ms (change|heartbeat) \Kws=\[[^]]*\]' <<< "$clean" | head -1)
    beforeRecover=$(pick 'recover:before')
    afterTop=$(pick 'recover:after-toplevels')
    afterWs=$(pick 'recover:after-workspaces')
    final=$(grep -oP 'PROBE \+\d+ms final \K.*' <<< "$clean" | tail -1)

    # The race window, measured from this boot's own log.
    conn=$(grep -oP '^\S+ \K\S+(?=.*event socket connected)' <<< "$clean" | head -1)
    parse=$(grep -oP '^\S+ \K\S+(?=.*Parsing workspaces response)' <<< "$clean" | head -1)
    width=$(python3 -c "
import sys,datetime
try:
    a=datetime.datetime.strptime('$conn','%H:%M:%S.%f'); b=datetime.datetime.strptime('$parse','%H:%M:%S.%f')
    print(int((b-a).total_seconds()*1000))
except Exception: print('?')")

    broken=$([[ "$(grep -oP 'ws=\[\K[^]]*' <<< "$beforeRecover")" != "$truth" ]] && echo YES || echo no)

    echo "$TAG-$(printf %03d "$n") window=${width}ms broken=$broken truth=[$truth]"
    echo "    postSnapshot=$postSnapshot"
    echo "    beforeRecover=$beforeRecover afterToplevels=$afterTop afterWorkspaces=$afterWs"
    echo "    final=$final"
done
