# Root cause: workspace dots missing after a cold start

Resolves [#119](https://github.com/bhdai/quickshell_config/issues/119). Follows
[#117](https://github.com/bhdai/quickshell_config/issues/117), which supplied the three
candidate mechanisms this ticket had to choose between.

Everything below was **reproduced on this machine**, against Quickshell `0.3.0`
(source at commit `59e9c47`) and Hyprland `0.56.1` (`5c9377c`), with the unmodified
config from this repo. The harness is in `docs/research/workspace-startup-race/`.

## The answer

Candidate 1 from #117 is the cause: **the startup snapshot races the event stream, and
its removal pass deletes workspaces the events had just created.** Candidates 2
(`workspacev2` gated on a null `bFocusedMonitor`) and 3 (`makeRequest` short read) never
fired in ~40 boots; `focusedMonitor` was populated on every single one.

The failure is **shell-wide**, in the `Hyprland` singleton, not in
`WorkspaceIndicator.qml`. The widget renders a broken model faithfully. That discharges
Q7 the same way #117 predicted.

The mechanism, from a captured failing boot:

```
21:38:19.172  Making request: "j/workspaces"        <- Hyprland composes the reply now
21:38:19.203  createworkspacev2>>11,11  -> created  <- events arrive first
21:38:19.203  createworkspacev2>>12,12  -> created
21:38:19.204  createworkspacev2>>13,13  -> created
21:38:19.204  createworkspacev2>>14,14  -> created
21:38:19.205  Parsing workspaces response           <- reply predates 11..14
              => removal pass deletes 11, 12, 13, 14
```

Final state of that boot: the model held workspaces `1,2,3,4` — all four destroyed in the
compositor minutes earlier — while Hyprland held `11,12,13,14`. It never repaired itself.

`connection.cpp:668-681` runs the removal pass whenever `canCreate` is set, and the
startup snapshot is the one call that sets it (`connection.cpp:91`). Any workspace created
by an event between Hyprland composing that reply and Quickshell parsing it is deleted as
"not in the reply".

## Why it happens at session start and nowhere else

Two conditions have to coincide, and `exec-once` is the only moment both hold.

**The window has to be open.** It runs from the shell issuing `j/workspaces` to the shell
parsing the answer. Measured on this machine:

| condition | window |
| --- | --- |
| bare probe shell, idle system | 1 ms |
| this repo's config, warm page cache | 30–50 ms |
| this repo's config, cold page cache | 120–165 ms |
| this repo's config, 8 CPU hogs | up to 457 ms |

The shell's own weight is what opens it. The `Hyprland` singleton is constructed the first
time QML names it, but the reply is not parsed until the main thread reaches the event
loop — after the rest of the config has loaded. On a cold boot that is hundreds of
milliseconds of QML, fonts, services and first-frame work, all while Hyprland keeps
emitting.

**Something has to create a workspace inside it.** `autostart.lua:50-52` pins zen, ghostty
and thunderbird to workspaces 1/2/3 from the same `hl.on("hyprland.start")` block that
launches quickshell, so their `createworkspacev2` events land in exactly that region.

This is also the whole explanation for the `sleep` workaround: with a delay, the apps have
already created their workspaces before the shell starts, so the snapshot contains them
and no create event arrives during the window. It never fixed anything — it moved the
shell out of the way.

## Second corruption mode: `id = -1` ghosts

One captured boot ended with six workspaces whose `id` was `-1`:

```
ws=[-1,-1,-1,-1,-1,-1,1,6,8,9]   (compositor: 1..10)
```

Same root cause, one step further. The stale snapshot deletes workspaces 2,3,4,5,7,10;
then the `j/clients` reply — which still lists those clients on workspaces named "2", "3",
… — resurrects them through
`HyprlandToplevel::updateFromObject` (`hyprland_toplevel.cpp:82`), which calls
`findWorkspaceByName(name, /*createIfMissing=*/true)` **without an id**, so the default
`-1` sticks (`connection.cpp:609-611`).

This matters to the widget: the delegate matches with
`Hyprland.workspaces.values.find(w => w.id === workspaceId)`, which can never match a
ghost. Those dots render as empty even though the workspace holds windows, and
`maxWorkspaceId` is computed from a set whose maximum is wrong.

## What recovers, and what does not

Tested against a deterministically broken boot (model `2,3,4,11`, compositor
`11,12,13,14`):

| attempt | result |
| --- | --- |
| wait | nothing; the state is permanent |
| switch to a missing workspace | **that one workspace only** comes back |
| `Hyprland.refreshWorkspaces()` alone | no-op — cannot create (`qml.cpp:48`) |
| `Hyprland.refreshToplevels()` **then** `refreshWorkspaces()` | **every workspace holding a window comes back, with correct ids** |
| `hyprctl reload` | full repair, including deleting phantoms |

Two of those are new, and one corrects #117.

**Switching partially heals.** `workspacev2` calls
`findWorkspaceByName(name, true, id)` (`connection.cpp:409`) — with `createIfMissing` *and*
a real id. So the workspace you switch to is restored, and every other missing one stays
missing. That is precisely the user's report of "switching workspace doesn't fix it": it
fixes one dot, silently, and leaves the rest.

**A QML-side repair does exist.** #117 concluded that "any widget-local retry is dead on
arrival" from `refreshWorkspaces()` passing `canCreate = false`. That is true of
`refreshWorkspaces()` *alone*, but the pair works, because two gates that are each closed
open in sequence:

1. `refreshToplevels()` has no `canCreate` gate and re-creates the workspaces as `-1`
   ghosts, via the `findWorkspaceByName(name, true)` path above.
2. `refreshWorkspaces()`'s parse has a name-based fallback for entries whose id is still
   `-1` (`connection.cpp:643-649`). It matches the ghosts, so `existed` is true, and
   `updateFromObject` writes the real id — no creation required.

Observed doing exactly that:

```
+13793ms recover:before          ws=[2,3,4,11]
+13847ms (after refreshToplevels) ws=[-1,-1,-1,2,3,4,11]
+14350ms (after refreshWorkspaces) ws=[2,3,4,11,12,13,14]
```

The limit is that neither call can *delete*, so phantom workspaces — entries for
workspaces the compositor no longer has — survive. Only `hyprctl reload` clears those:
`configreloaded` is the one event path that re-runs a snapshot with `canCreate = true`
(`connection.cpp:274-278`).

For this repo's actual failure that limit is mild. A real cold start *creates* workspaces
inside the window, it does not move them, so the failure is purely "missing"; the phantoms
above are an artifact of how the reproducer forces the timing. A phantom workspace also
costs the widget much less than a missing one — it renders as an empty dot.

## The widget is not implicated, but it does amplify

`maxWorkspaceId` (`WorkspaceIndicator.qml:49-61`) is a faithful function of the model.
Given a model missing workspace 10, it computes 9 dots, correctly. The data is absent, not
unrendered — sub-question 3 in #119.

Two widget-side behaviours make the singleton's bug worse than it needs to be, and both
should be handled in the rewrite:

- `find(w => w.id === workspaceId)` cannot match an `id = -1` ghost, so an occupied
  workspace renders as an empty dot.
- Nothing ever re-queries. The delegate is a pure binding on the model, so a model that is
  wrong at second one is wrong forever.

## Answers to #119's sub-questions

1. **Reproduced**, without touching the live session — see below. Logs from failing boots
   are in `docs/research/workspace-startup-race/logs/`.
2. **The event stream is not dead; only the initial snapshot is wrong.** Events flow
   normally throughout — in the failing boots, `workspacev2` kept updating
   `focusedWorkspace` correctly seconds later. `ActiveWindow` and the brightness OSD are
   unaffected, which is consistent with the user only ever noticing the dots.
3. **No.** The widget's binding is correct; the model it reads is corrupt.
4. **Yes, decisively.** The concurrent app launch is the necessary second condition. With
   no workspace created during the window, no boot has ever failed here.
5. **Root cause** as above.

## How it was reproduced

Everything runs in a nested Hyprland on the host session, so no logout or reboot is
involved and the live shell is never touched. `docs/research/workspace-startup-race/`:

- `boot.sh` — one simulated cold start: a nested Hyprland whose `exec-once` launches the
  observed shell and N stand-in apps pinned to workspaces, mirroring `autostart.lua`.
- `realshell/Probe.qml` — instrumentation dropped into a copy of this config. Logs the
  singleton's model, the monitor, and the exact `maxWorkspaceId` the widget would compute,
  on every change.
- `boot-trigger2.sh` + `trigger.py` — the deterministic reproducer. It tails the shell's
  log and, the instant the shell issues `j/workspaces`, moves pre-mapped windows onto
  fresh workspaces by writing straight to Hyprland's request socket. Spawning `hyprctl`
  costs ~90 ms and overshoots the window; a raw socket write costs ~1 ms and lands inside
  it every time.
- `hunt-real.sh`, `sweep.sh` — randomised batches, used to establish that unaimed boots
  fail only when the window is wide.

Rates observed: 0/12 with a warm cache and a ~35 ms window; 2/6 with a cold cache and a
~124 ms window; 3/4 with the trigger. The trigger's one miss had a 34 ms window, narrower
than the ~55 ms Hyprland itself takes to act on the batch — so the reproducer is reliable
whenever the window is wider than that, which is every cold boot.

**Any fix should be validated against `boot-trigger2.sh`.**

## Limits

- The stand-in apps are Quickshell `FloatingWindow`s, not zen/ghostty/thunderbird. They
  produce the same `createworkspacev2` events; they do not reproduce those apps' real
  startup timings or I/O load.
- The deterministic reproducer creates its workspaces by *moving* windows rather than
  mapping them, because a window map costs ~90 ms and cannot be aimed. The singleton sees
  the same events either way, but it means that reproducer also destroys the original
  workspaces, which is what produces the phantom entries discussed above.
- No failing boot of the *live* session was captured. The reproduction is of the same
  mechanism in a nested compositor with the same config, Quickshell and Hyprland.
- The nested compositor was run under CPU load in some batches; two of those boots came up
  with no monitor at all, which is a harness artifact and was discarded.
