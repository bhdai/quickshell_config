# Startup race harness

Reproduces the cold-start workspace bug from
[#119](https://github.com/bhdai/quickshell_config/issues/119) in a nested Hyprland, so it
never touches the live session. Findings are in `../workspace-startup-race.md`.

## Setup

The scripts hardcode `JOB=` at the top — set it to wherever you unpack this. Then build
the observed shell, which is a copy of this config with the probe dropped in:

```sh
mkdir -p $JOB/realshell
tar -cf - --exclude=.git --exclude=.claude -C /path/to/quickshell_config . | tar -xf - -C $JOB/realshell
cp realshell/Probe.qml $JOB/realshell/
# then append `Probe {}` as the last child of ShellRoot in $JOB/realshell/shell.qml
```

`Probe.qml` logs the `Hyprland` singleton's workspace ids, monitors, focused workspace, and
the exact `maxWorkspaceId` that `WorkspaceIndicator.qml` would compute — on load, on every
change, once a second, and at exit. It also tries a QML-side repair at `PROBE_RECOVER` ms.

## Running

```sh
./boot-trigger2.sh runs/x 4     # deterministic: breaks whenever the window exceeds ~55ms
./hunt-real.sh 10 16 1000 400 t # randomised: only breaks when the window is wide
LOAD=8 ./hunt-real.sh 10 16 1000 400 t   # ...so add CPU contention to widen it
```

Read the verdict from `runs/x/meta.txt` (`model:` vs `truth:`) and the mechanism from
`runs/x/probe.log`.

## Why the trigger is a raw socket write

`boot-trigger2.sh` must create a workspace inside the window between the shell issuing
`j/workspaces` and parsing the reply — tens of milliseconds. Spawning `hyprctl` costs
~90 ms and always overshoots; `trigger.py` connects to Hyprland's request socket and
writes on the marker instead, for ~1 ms. Windows are moved rather than mapped for the same
reason: mapping a window costs ~90 ms and cannot be aimed.
