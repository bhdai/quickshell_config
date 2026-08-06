#!/usr/bin/env bash
# Run N simulated cold starts and diff the Hyprland singleton's final model against
# the compositor's own answer. Prints one verdict line per boot.
#
#   ./sweep.sh <n-boots> <n-apps> <max-delay-ms> <tag>
set -uo pipefail

JOB=/home/dai/.claude/jobs/e2a0bfe0/tmp
N=${1:-20}
APPS=${2:-9}
MAXD=${3:-250}
TAG=${4:-sweep}

export PROBE_LIFETIME=${PROBE_LIFETIME:-8000}

for n in $(seq 1 "$N"); do
    OUT="$JOB/runs/$TAG-$(printf %03d "$n")"
    rm -rf "$OUT"

    delays=()
    for _ in $(seq 1 "$APPS"); do delays+=($((RANDOM % (MAXD + 1)))); done

    timeout 90 "$JOB/boot.sh" "$OUT" "${delays[@]}" >/dev/null 2>&1

    final=$(sed 's/\x1b\[[0-9;]*m//g' "$OUT/probe.log" 2>/dev/null | grep -oP 'PROBE \+\d+ms final \K.*' | tail -1)
    model=$(grep -oP 'ws=\[\K[^]]*' <<< "$final")
    truth=$(grep -oP '^workspaces: \K.*' "$OUT/meta.txt" 2>/dev/null | sed 's/,$//')
    fmon=$(grep -oP 'focusedMon=\K\S+' <<< "$final")
    fws=$(grep -oP 'focusedWs=\K\S+' <<< "$final")
    truthActive=$(grep -oP '^activeWorkspace: \K.*' "$OUT/meta.txt" 2>/dev/null)

    verdict=OK
    [[ -z $final ]] && verdict=NOLOG
    [[ $model != "$truth" ]] && verdict=WS-MISMATCH
    [[ $fmon == NULL ]] && verdict=NULL-MONITOR
    [[ $fws != "$truthActive" ]] && verdict="${verdict}/ACTIVE-MISMATCH"

    echo "$TAG-$(printf %03d "$n") delays=[${delays[*]}] verdict=$verdict model=[$model] truth=[$truth] focusedWs=$fws truthActive=$truthActive"
done
