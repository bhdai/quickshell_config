#!/usr/bin/env bash
# Aim a burst of workspace-creating window maps at the instant the shell parses its
# startup snapshot, and check whether the model loses any of them.
#
#   ./hunt.sh <n-boots> <n-apps> <spread-ms> <tag>
set -uo pipefail

JOB=/home/dai/.claude/jobs/e2a0bfe0/tmp
N=${1:-20}
APPS=${2:-10}
SPREAD=${3:-40}
TAG=${4:-hunt}

export PROBE_LIFETIME=${PROBE_LIFETIME:-8000}

# A fakeapp maps its window ~180ms after exec-once plus its own delay; the probe
# parses its snapshot ~134ms after it starts. Line the two up.
for n in $(seq 1 "$N"); do
    OUT="$JOB/runs/$TAG-$(printf %03d "$n")"
    rm -rf "$OUT"

    sleep_ms=$((600 + RANDOM % 1200))
    export PROBE_SLEEP=$(printf '%d.%03d' $((sleep_ms / 1000)) $((sleep_ms % 1000)))
    centre=$((sleep_ms - 46))

    delays=()
    for _ in $(seq 1 "$APPS"); do
        d=$((centre - SPREAD + RANDOM % (2 * SPREAD + 1)))
        ((d < 0)) && d=0
        delays+=("$d")
    done

    timeout 90 "$JOB/boot.sh" "$OUT" "${delays[@]}" >/dev/null 2>&1

    final=$(sed 's/\x1b\[[0-9;]*m//g' "$OUT/probe.log" 2>/dev/null | grep -oP 'PROBE \+\d+ms final \K.*' | tail -1)
    model=$(grep -oP 'ws=\[\K[^]]*' <<< "$final")
    truth=$(grep -oP '^workspaces: \K.*' "$OUT/meta.txt" 2>/dev/null | sed 's/,$//')
    fmon=$(grep -oP 'focusedMon=\K\S+' <<< "$final")
    fws=$(grep -oP 'focusedWs=\K\S+' <<< "$final")
    truthActive=$(grep -oP '^activeWorkspace: \K.*' "$OUT/meta.txt" 2>/dev/null)

    verdict=OK
    [[ -z $final ]] && verdict=NOLOG
    [[ -n $final && $model != "$truth" ]] && verdict=WS-MISMATCH
    [[ $fmon == NULL ]] && verdict=NULL-MONITOR
    [[ -n $final && $fws != "$truthActive" ]] && verdict="${verdict}/ACTIVE-MISMATCH"

    echo "$TAG-$(printf %03d "$n") probeSleep=$PROBE_SLEEP verdict=$verdict model=[$model] truth=[$truth] focusedWs=$fws truthActive=$truthActive"
done
