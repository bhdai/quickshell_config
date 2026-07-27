# Reload while locked — observed behaviour

Settles the contradiction between
[#46](https://github.com/bhdai/quickshell_config/issues/46) (read from
`session_lock.cpp`) and [#48](https://github.com/bhdai/quickshell_config/issues/48)
(read from `rootwrapper.cpp`) about whether a QML hot reload can unlock a locked
screen. Everything below is observed, not inferred; the harness is in
[`spikes/reload-lock/`](../../spikes/reload-lock/).

Quickshell 0.3.0, Hyprland 0.56.0, 2026-07-28.

## Verdict

**Both were right, about different things, and both were wrong about the fix.**

- #46's four-row table is **confirmed in every row**, including the row that bites:
  a successful reload *does* unlock a locked screen when lock state lives in an
  ordinary QML property.
- #48's claim is **confirmed** for the case it was actually about: a *failed* reload
  (QML error) leaves the old generation and its lock completely untouched.
- The one mitigation both tickets found independently — **set `reloadableId` on the
  `WlSessionLock`** — is **falsified**. It changes nothing. See
  [reloadableId is inert](#reloadableid-is-inert).

## How it was run

Each row runs against a **nested Hyprland**, started as a Wayland client of the real
session. `ext-session-lock-v1` binds a lock to the compositor that granted it, so the
lock under test covers the nested instance's own window and cannot reach the desktop.
That removes the TTY-standby hazard #57 was written around: rows that strand a session
strand only the nested one.

Distinguishing *unlocked* from *locked with no client* needs a second observer — from
the shell's own logs both read as `locked == false`. After every row a fresh client
tries to lock the nested compositor. Hyprland refuses a lock still held by a dead
client (`misc:allow_session_lock_restore` defaults false, per #48), so a **denied**
probe means stranded and a **granted** probe means genuinely unlocked.

## The table

`persisted` = lock state in `PersistentProperties`; `ordinary` = a plain QML property
that a new generation constructs as `false`. "flat" = `WlSessionLock` as a direct child
of `ShellRoot`; "module" = nested in a `LockModule.qml` (`Scope`), the shape the real
`lock/` module will have.

| Run | Shape | `reloadableId` | Lock state | Reload trigger | Matched? | New `wantLock` | Outcome | Compositor after |
|---|---|---|---|---|---|---|---|---|
| R1 | flat | `"spikeLock"` | persisted | edit file contents | yes | `true` | lock preserved, new generation adopts | locked, live client |
| R2 | flat | `"spikeLock"` | ordinary | edit file contents | yes | `false` | **screen unlocks** | unlocked |
| R3 | flat | changed mid-lock | persisted | change the id itself | **yes** | `true` | lock preserved | locked, live client |
| R4 | flat | changed mid-lock | ordinary | change the id itself | **yes** | `false` | **screen unlocks** | unlocked |
| R5 | flat | `"spikeLock"` | persisted | deliberate syntax error | reload fails | — | old generation survives, lock held | locked, live client |
| R6 | flat | **unset** | persisted | edit file contents | yes | `true` | lock preserved | locked, live client |
| R7 | flat | **unset** | persisted | reorder two siblings | **no** | `true` | **`qFatal`, exit 255** | **locked, no client** |
| R8 | flat | `"spikeLock"` | persisted | reorder two siblings | **no** | `true` | **`qFatal`, exit 255** | **locked, no client** |
| R9 | flat | **unset** | ordinary | reorder two siblings | **no** | `false` | no crash, lock dropped silently | **locked, no client** |
| R10 | module | `"spikeLock"` | persisted | edit file contents | yes | `true` | lock preserved | locked, live client |
| R11 | module | `"spikeLock"` | persisted | add an item above the module in `shell.qml` | **no** | `false` | no crash, lock dropped silently | **locked, no client** |
| R12 | module | **unset** | persisted | add an item above the module in `shell.qml` | **no** | `false` | no crash, lock dropped silently | **locked, no client** |

The `qFatal` string is exactly the one #46 predicted:
`FATAL: Tried to show lockscreen surfaces without active lock`.

Mapping onto #46's rows: row 1 = R1/R3/R6/R10, row 2 = R2/R4, row 3 = R7/R8, row 4 =
R9/R11/R12. All four confirmed.

Rows 3 and 4 differ only in whether the *persisted state* matched while the lock did
not. R7/R8 move only the lock's index, so `PersistentProperties` still adopts, the new
`wantLock` is `true`, and the crash path runs. R11/R12 move the whole module, so the
persisted state fails to match too, the new `wantLock` is `false`, and the lock is
dropped quietly instead. **Quiet is not better** — both leave the session locked with
no client, recoverable only from a TTY.

## `reloadableId` is inert

Four comparisons, all negative:

- **R6 vs R1** — no `reloadableId` at all, ordinary edit: still matched, lock preserved.
- **R3/R4** — the `reloadableId` *changed* between generations: still matched.
- **R8 vs R7** — `reloadableId` set, siblings reordered: still unmatched, still `qFatal`.
- **R12 vs R11** — same, for the nested module shape: byte-identical outcomes.

What actually decides matching is **index position among the enclosing
`ReloadPropagator`'s children**. `ShellRoot` is a `ReloadPropagator`, and it hands the
old child at index *i* to the new child at index *i*. For a `WlSessionLock` reached that
way the id is never consulted, so setting it buys nothing and — worse — reads in a spec
as though the hazard has been handled.

This is the one place where reading the source misled both research tickets. Neither
observed it; both recommended it; #46 called it "non-negotiable".

> Not established: whether `reloadableId` matters for a `Reloadable` that the propagator
> *cannot* reach positionally — e.g. one moved between parents, or under a `LazyLoader`.
> The lock module will not be in that position, so the spike did not chase it.

## Reload-safety contract for the build spec

1. **Persist `lockRequested` in `PersistentProperties`.** This is the mitigation that
   survives contact with the experiment. Without it, saving *any* loaded QML file while
   the screen is locked opens it (R2, R4). With it, ordinary edits are safe (R1, R6, R10).
2. **Do not spec `reloadableId` as a safety measure.** Harmless to set, but it does not
   make a reload safe, and it must not be what the spec leans on.
3. **The real constraint is structural, and it belongs in the spec as a rule for humans:
   while the screen is locked, do not add, remove, or reorder items in `shell.qml`'s
   child list** (or in the lock module's enclosing scope). That single class of edit is
   what strands the session — with a crash (R7/R8) or without one (R9, R11, R12) — and
   recovery is `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'` from a TTY,
   per #48. Editing file *contents* is safe; editing the *tree shape* is not.
4. **A broken edit is safe and self-healing.** A QML syntax error while locked keeps the
   old generation, keeps the lock, and keeps the surface on screen (R5). IPC stops
   answering (`Not ready to accept queries yet`) for as long as the config is in the
   failed state, then resumes when the file is repaired — same generation, lock never
   dropped. So a typo while locked is recoverable by fixing the typo.
5. **`secure` rises again on every preserved reload.** The new generation's
   `WlSessionLock` starts `secure == false` and transitions to `true` once its surfaces
   are up (R1). Anything armed on the `secure` rising edge — notably the fingerprint
   arming decided in [#53](https://github.com/bhdai/quickshell_config/issues/53) — will
   re-arm on every hot reload that happens while locked. That is benign for fingerprint
   (it re-arms an already-armed factor) but any future edge-triggered logic needs to
   expect it.

## Secondary observations

- **No `duplicate_output` protocol error** on any matched reload. #46 flagged this
  `[inferred]` and could not confirm it; across R1/R3/R6/R10 no protocol error appears,
  and old surfaces are destroyed after the new ones are created without complaint.
  Question closed, negative.
- **A denied lock kills the client.** When a fresh client asks to lock a compositor that
  is still locked by a dead one, Hyprland refuses and the connection dies with
  `wl_display#1: error 0: invalid object 42` / `The Wayland connection experienced a
  fatal error`. Any supervision or pre-lock fallback that retries into a stranded
  compositor will die noisily rather than degrade — relevant to
  [#52](https://github.com/bhdai/quickshell_config/issues/52).
- **`secure` was seen `true` while `locked` was `false`, once.** On one R12 run the new
  generation reported `locked=false secure=true` despite never having held the lock; a
  repeat of the same row reported `secure=false`. Seen once and not reproduced, so it is
  recorded rather than claimed — but anything that treats `secure` as a standalone
  "the screen is protected" signal should read `locked` too.
- **New generation before old teardown**, as #46 read it: the new `WlSessionLock` is
  created and its `locked` binding evaluated *before* the old generation is destroyed.
- **The file watcher ignores some edits.** No reload fired for `touch` (mtime only) or
  for `sed -i` (which replaces the file by rename); only rewriting the existing file's
  contents triggered one. Editors that save via atomic rename may therefore not hot-reload
  at all. Observed only through this harness, on one machine — noted, not established.

## Caveats

- Run against a **nested** Hyprland, not the real session. The reload behaviour under
  test is Quickshell-side (`onReload` / `realizeLockTarget` / `updateSurfaces`) and is
  compositor-independent; the compositor-side facts used here — refusing a lock held by
  a dead client — match what #48 verified live on the same Hyprland version.
- **Nothing was visually confirmed.** Every conclusion comes from Quickshell's log, its
  IPC state, and the protocol-level probe. "Screen unlocks" means the compositor released
  the lock and a fresh client could take it, not that a human watched it open.
- Single nested output. Multi-monitor reload behaviour (this machine has `eDP-1` plus a
  mirroring `HDMI-A-1`) was not exercised.
