# Spike: reload while locked

Throwaway harness for [#57](https://github.com/bhdai/quickshell_config/issues/57).
Findings are written up in [`docs/research/reload-while-locked.md`](../../docs/research/reload-while-locked.md);
this directory only holds the apparatus that produced them.

It is **not** the lock module. It exists to answer one question — what a QML hot
reload does to an active `WlSessionLock` — and nothing here should be reused in
`lock/`.

## Running it

```sh
./run.sh all                              # the whole matrix
./run.sh R2 spikeLock false nudge         # one row: <name> <lockId> <persist> <trigger>
```

Each row runs against a **nested Hyprland** started as a Wayland client of the real
session. `ext-session-lock-v1` locks only the compositor that grants it, so the lock
under test covers the nested instance's own 640x400 window and cannot reach the
desktop. That is what makes this safe to run unattended — no second TTY, no
`hl.clear_crashed_lockscreen()` standby.

The harness *does* wedge the nested compositor regularly (that is half the results),
so `run.sh` restarts it before every row.

## Knobs

`shell.qml` carries two, edited in place by `edits.py`:

- `lockId` — the `WlSessionLock`'s `reloadableId`; `""` reproduces leaving it unset.
- `persistLockState` — `true` keeps lock state in `PersistentProperties`, `false` in
  an ordinary QML property that a new generation constructs as `false`.

`nested/` holds the same harness re-rooted into a `LockModule.qml` (a `Scope` under
`ShellRoot`), which is the shape the real module will have.

## Reading a result

Every row prints the IPC `status` before and after the reload, whether the process
survived, and a **verdict** from a probe: a fresh client tries to lock the nested
compositor afterwards. Hyprland refuses a lock still held by a dead client, so a
denied probe means the session was left *locked with no client*, and a granted one
means it genuinely unlocked. Without that probe the two are indistinguishable from
the shell's own logs — in both cases its `locked` reads `false`.
