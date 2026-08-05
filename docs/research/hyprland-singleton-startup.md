# How Quickshell 0.3.0's Hyprland singleton connects, and what breaks at startup

Research for [How Quickshell's Hyprland singleton connects at startup and whether it
recovers](https://github.com/bhdai/quickshell_config/issues/117), performed on 2026-08-05.
Part of [#116](https://github.com/bhdai/quickshell_config/issues/116).

## Executive answer

**The map's hypothesis is not supported.** The `socket2` event stream is not the thing that
fails, and it cannot be, because on this machine's exact configuration both Hyprland IPC
sockets are already bound and listening before quickshell is spawned. What is fragile is
the *other* half: the one-shot `j/monitors` / `j/workspaces` / `j/clients` snapshot taken
over the **request** socket (`.socket.sock`), which races the event stream and has no
retry.

The "permanently deaf" half of the hypothesis is correct, but for a different reason than
assumed. Three verified properties of v0.3.0 combine into it:

1. **The snapshot's removal pass is unconditional.** `refreshWorkspaces(true)` and
   `refreshMonitors(true)` delete every object that is absent from the JSON reply — even
   objects that a `createworkspacev2` event created moments earlier from a *newer* state
   than the snapshot. Event handling and snapshot parsing are interleaved with no
   ordering guarantee, and I observed that interleave happening on this machine.
2. **The QML-facing `refresh*()` calls cannot create objects.** `Hyprland.refreshWorkspaces()`
   and `Hyprland.refreshMonitors()` call the internal method with `canCreate = false`, so
   against an emptied model they are literally no-ops. Nothing reachable from QML can
   rebuild the workspace list.
3. **A null `focusedMonitor` silently swallows every workspace switch.** The `workspacev2`
   handler is wrapped in `if (this->bFocusedMonitor != nullptr)`. On a single-monitor
   setup Hyprland emits `focusedmon` only when the focused monitor *changes*, so it never
   fires again — the null is permanent, and so is the deafness.

There is no reconnect, no retry, no backoff, and no readiness signal exposed to QML.
`HyprlandIpc` is a process-lifetime static, so a quickshell hot reload does not
re-establish anything either.

## Evidence and confidence labels

- **Verified in source** — read directly from Quickshell v0.3.0, commit
  [`59e9c47`](https://git.outfoxxed.me/quickshell/quickshell/src/tag/v0.3.0), or from
  Hyprland v0.56.1, commit
  [`5c9377c`](https://github.com/hyprwm/Hyprland/tree/v0.56.1). Both are the versions
  actually installed here (`quickshell 0.3.0-2`, `hyprland 0.56.1-3`).
- **Observed locally** — read out of the running instance's log or process table on
  2026-08-05.
- **Documented** — stated by `quickshell.org/docs/v0.3.0`.
- **Inference** — follows from the above but was not reproduced.

Nothing here was reproduced against a failing run. The current instance started
successfully, and quickshell's logs live in `$XDG_RUNTIME_DIR`, so no log of a failed
boot survives. Confirming *which* of the mechanisms below actually fires is
[#119](https://github.com/bhdai/quickshell_config/issues/119)'s job; this note supplies
the candidates and how to tell them apart.

## 1. When it connects, and to what

**Verified in source.** `Hyprland` is a C++ `QML_SINGLETON` (`ipc/qml.hpp:45-46`), so it is
constructed lazily, the first time QML touches it. `HyprlandIpcQml`'s constructor calls
`HyprlandIpc::instance()` (`ipc/qml.cpp:13-14`), which is a **process-lifetime static**:

```cpp
HyprlandIpc* HyprlandIpc::instance() {
	static HyprlandIpc* instance = nullptr; // NOLINT
	if (instance == nullptr) instance = new HyprlandIpc();
	return instance;
}
```
*(`ipc/connection.cpp:264-272`)*

It is never destroyed and never rebuilt. **A quickshell hot reload creates a fresh QML
engine and therefore a fresh `HyprlandIpcQml`, but the underlying `HyprlandIpc` — and its
connection state — survives untouched.** Saving a file cannot fix a broken connection.
(The engine-per-reload part is inference; the process-static part is verified.)

The constructor (`ipc/connection.cpp:40-94`) does, in order:

1. Read `$HYPRLAND_INSTANCE_SIGNATURE`. If empty: `qWarning() << "$HYPRLAND_INSTANCE_SIGNATURE
   is unset. Cannot connect to hyprland."` and **`return`** — no paths set, nothing else
   ever happens.
2. Resolve the instance directory as `$XDG_RUNTIME_DIR/hypr/$HIS`, falling back to
   `/tmp/hypr/$HIS`. If neither is a directory: `qWarning() << "Unable to find hyprland
   socket. Cannot connect to hyprland."` and **`return`** — same permanent death.
3. Set `mRequestSocketPath = <dir>/.socket.sock` and `mEventSocketPath = <dir>/.socket2.sock`.
4. Wire `errorOccurred` / `stateChanged` / `readyRead` on the event socket.
5. Issue **one request first** — `j/status`, to detect Hyprland's Lua config mode — and do
   everything else from its callback:

```cpp
this->makeRequest("j/status", [&, this](bool success, QByteArray resp) {
    if (success) { /* set bUsingLua */ }
    else { qCWarning(logHyprlandIpc) << "Hyprland ipc status request failed."; }

    this->eventSocket.connectToServer(this->mEventSocketPath, QLocalSocket::ReadOnly);
    this->refreshMonitors(true);
    this->refreshWorkspaces(true);
    this->refreshToplevels();
});
```
*(`ipc/connection.cpp:77-93`)*

Two things follow:

- **The event socket is not connected until a full round trip on the request socket has
  completed or failed.** Every Hyprland event emitted in that window is lost outright.
  The connection is attempted on both branches, so a failed `j/status` does not skip it.
- **Connection is eager relative to first property access** — it all happens in the
  constructor's callback, not on first read of `workspaces`. But the constructor itself is
  lazy, so the clock starts when QML first names `Hyprland`.

Sockets used: `.socket.sock` for every request (`j/status`, `j/monitors`, `j/workspaces`,
`j/clients`, `dispatch`), `.socket2.sock` read-only for the event stream. Both paths are
exposed as the constant QML properties `Hyprland.requestSocketPath` and
`Hyprland.eventSocketPath` (**documented**; empty strings if the constructor bailed at
step 1 or 2).

### Requests get a fresh socket every time

**Verified in source** (`ipc/connection.cpp:171-201`). `makeRequest` allocates a new
`QLocalSocket`, connects, writes, reads, and deletes it. The request path therefore
**does not share a socket with the event stream** and does not care whether the event
stream is alive. This is the direct answer to "do `refresh*()` share the same dead
socket?" — they do not.

## 2. Failure and retry behaviour: there is none

**Verified in source.**

| Failure | Handling |
| --- | --- |
| `$HYPRLAND_INSTANCE_SIGNATURE` unset | `qWarning`, constructor returns. Permanent. |
| Instance directory missing | `qWarning`, constructor returns. Permanent. |
| Event socket connect fails | `eventSocketError` logs `qWarning() << "Unable to connect to hyprland event socket:" << error`. **No retry, no timer, no reconnect.** (`connection.cpp:99-105`) |
| Event socket disconnects later | `eventSocketStateChanged` logs `"Hyprland event socket disconnected."` and sets `valid = false`. **No reconnect.** (`connection.cpp:107-117`) |
| A request fails | `qCWarning(logHyprlandIpc) << "Error making request:"`, callback invoked with `success = false`. Each `refresh*` callback then does `if (!success) return;`. **No retry.** |

The retry used to exist. `refreshWorkspaces`/`refreshMonitors` carried a `tryAgain`
parameter ("sometimes fails randomly, so we give it another shot") added in
[`ef1a413`](https://git.outfoxxed.me/quickshell/quickshell/commit/ef1a413) (2024-06-06)
and **deliberately removed** in [`ae762f5`](https://git.outfoxxed.me/quickshell/quickshell/commit/ae762f5)
(2024-06-18), whose real fix was adding the missing `requestSocket->flush()`. The same
commit also removed the `QTimer::singleShot(0, ...)` that had deferred the initial
connect by one event-loop cycle. v0.3.0 has neither.

### Observable signals of failure

- **Log lines.** The two constructor bail-outs and the event-socket errors use bare
  `qWarning()`, which is always visible. `"Hyprland ipc status request failed."` and
  `"Error making request:"` use `qCWarning(logHyprlandIpc)`; the category
  `quickshell.hyprland.ipc` defaults to `QtWarningMsg` (`connection.cpp:36`), so those are
  visible by default too. `"Hyprland event socket connected."` is `qCInfo` — **not**
  visible by default; you need `-r 'quickshell.hyprland*=true'` on `qs log`.
- **Properties.** `Hyprland.requestSocketPath === ""` proves the constructor bailed. That
  is the only QML-visible signal of a hard failure.
- **`Hyprland.usingLua` is an accidental probe for this repo.** It is assigned only inside
  the `success` branch of the `j/status` callback (`connection.cpp:77-84`). This machine
  runs a Hyprland Lua config, so once startup has settled, `usingLua === false` means the
  initial `j/status` round trip failed. **Verified in source**; useful for #119.
- **There is no readiness signal.** `HyprlandIpc` emits a C++ `connected()` signal
  (`connection.hpp:118`, `connection.cpp:111`) but `HyprlandIpcQml` **does not forward it**
  — its signal list is `rawEvent`, `usingLuaChanged`, `focusedMonitorChanged`,
  `focusedWorkspaceChanged`, `activeToplevelChanged` (`ipc/qml.hpp:85-94`), and the docs
  list only `rawEvent`. There is no `valid`, `ready`, or `connected` property. Any
  readiness gate this repo builds has to be synthesised from observed state.

## 3. Initial population vs. the event stream

**Verified in source.** They are separate mechanisms, and they race.

Initial population is the three snapshot requests fired from the `j/status` callback:
`j/monitors` → `refreshMonitors(true)`, `j/workspaces` → `refreshWorkspaces(true)`,
`j/clients` → `refreshToplevels()`. The `true` is `canCreate`, whose declaration is
commented `// canCreate avoids making ghost workspaces when the connection races`
(`connection.hpp:109-111`) — upstream knows this path races.

Afterwards, the models are maintained purely from events (`onEvent`,
`connection.cpp:274-580`). The only event that re-runs a full snapshot with `canCreate =
true` is `configreloaded`.

**Observed locally**, from this boot's log (`qs log … -r 'quickshell.hyprland*=true'`),
the two paths interleave:

```
Making request: "j/status"
Hyprland event socket connected.
Making request: "j/monitors"
Making request: "j/workspaces"
Making request: "j/clients"
Received event: "createworkspacev2>>3,3"
Workspace created with id 3
Received event: "openwindow>>...,3,org.mozilla.Thunderbird,..."
parsing monitors response
Workspace "1" requested before creation, performing early init with id 1
Parsing workspaces response
Parsing j/clients response
```

Events emitted *after* the snapshot requests were sent are processed *before* the
snapshot replies are parsed. That is the hazard, because of what the removal pass does.

### The removal pass is not gated on `canCreate`

```cpp
if (canCreate) {
    auto removedWorkspaces = QVector<HyprlandWorkspace*>();
    for (auto* workspace: mList) {
        if (!ids.contains(workspace->bindableId().value())) removedWorkspaces.push_back(workspace);
    }
    for (auto* workspace: removedWorkspaces) { this->mWorkspaces.removeObject(workspace); delete workspace; }
}
```
*(`connection.cpp:668-681` — gated for workspaces)*

For monitors it is **not** gated at all (`connection.cpp:843-855`): any monitor absent
from the reply is removed and `deleteLater()`d, regardless of `canCreate`.

So if Hyprland produced the `j/workspaces` snapshot before workspace 3 existed, and
quickshell processed `createworkspacev2>>3,3` before parsing that reply, workspace 3 is
created by the event and then **deleted by the stale snapshot**. It never comes back:
`createworkspacev2` has already been consumed, and (see §4) no QML call can recreate it.

This is **inference** — I verified the code and observed the interleave, but did not catch
the deletion happening. It fits the reported symptom precisely, including why a `sleep`
cures it: with a few seconds' delay, workspaces 1/2/3 already exist when the snapshot is
taken, so there is nothing for the snapshot to be stale about.

**Relevant environment detail (observed locally):** the three exec-once apps pinned to
workspaces 1/2/3 are launched from the *same* `hl.on("hyprland.start")` block as
quickshell, so their workspace-creation events land in exactly this window.

## 4. Can `refresh*()` recover? Mostly no

**Verified in source** (`ipc/qml.cpp:48-50`):

```cpp
void HyprlandIpcQml::refreshMonitors()   { HyprlandIpc::instance()->refreshMonitors(false); }
void HyprlandIpcQml::refreshWorkspaces() { HyprlandIpc::instance()->refreshWorkspaces(false); }
void HyprlandIpcQml::refreshToplevels()  { HyprlandIpc::instance()->refreshToplevels(); }
```

The QML entry points pass `canCreate = false`. Inside the callbacks:

```cpp
if (!existed) {
    if (!canCreate) continue;   // workspaces: connection.cpp:654-657
    ...
}
```

So against an **empty or partially-wiped model**:

| Call | Effect |
| --- | --- |
| `Hyprland.refreshWorkspaces()` | Iterates the JSON, matches nothing, `continue`s past every entry. **No-op.** Cannot add a missing dot. |
| `Hyprland.refreshMonitors()` | Same. Cannot create a monitor. Can only update ones that already exist — but if one does exist, `HyprlandMonitor::updateFromObject` sets `focusedMonitor` when `focused: true` (`monitor.cpp:57-59`) and creates its active workspace via `findWorkspaceByName(…, /*createIfMissing=*/true)` (`monitor.cpp:46-52`). So it recovers focus *if* a monitor object survives. |
| `Hyprland.refreshToplevels()` | Has **no** `canCreate` gate (`connection.cpp:706-748`). Always creates. Fully recovers. |
| `Hyprland.monitorFor(screen)` | `findMonitorByName(screen->name(), !this->monitorsRequested)` (`connection.cpp:772-780`). Creates a stub monitor **only while `monitorsRequested` is false** — and that flag is set to `true` at the top of the first *successful* `j/monitors` callback (`connection.cpp:810`), before parsing. Once a reply has arrived, this escape hatch is closed. |

Note the ordering trap: they do not share a dead socket, so they *would* reach Hyprland
fine — they just refuse to create anything when they get there. This repo never calls
`Hyprland.monitorFor()` (it uses the global `Hyprland.focusedWorkspace` at
`modules/bar/WorkspaceIndicator.qml:23` and `Hyprland.focusedMonitor` in four other
modules), so the one escape hatch that exists is not wired up.

**The only full recovery reachable from outside is `hyprctl reload`**, whose
`configreloaded` event runs `refreshMonitors(true)`, `refreshWorkspaces(true)` and
`refreshToplevels()` (`connection.cpp:274-278`). If a `hyprctl reload` fixes a broken
boot, that is strong evidence the failure is snapshot-side rather than event-side —
a cheap discriminator for #119.

## 5. Why a workspace switch does not recover it

**Verified in source.** The `workspacev2` handler:

```cpp
} else if (event->name == "workspacev2") {
    auto args = event->parseView(2);
    auto id = args.at(0).toInt();
    auto name = QString::fromUtf8(args.at(1));

    if (this->bFocusedMonitor != nullptr) {
        auto* workspace = this->findWorkspaceByName(name, true, id);
        this->bFocusedMonitor->setActiveWorkspace(workspace);
    }
}
```
*(`connection.cpp:403-413`)*

If `bFocusedMonitor` is null, a workspace switch is **silently dropped** — no workspace
created, no active workspace set, no warning logged. And `bFocusedWorkspace` is bound to
`bFocusedMonitor->activeWorkspace` (`connection.cpp:59-62`), so `Hyprland.focusedWorkspace`
— the property `WorkspaceIndicator.qml:23` reads — stays null forever.

`bFocusedMonitor` is set from exactly two places: a monitor's `focused: true` in a
`j/monitors` reply (`monitor.cpp:57-59`), and the `focusedmon` event
(`connection.cpp:388-402`).

**Verified in Hyprland source** (`src/desktop/state/FocusState.cpp:272-291`):

```cpp
void CFocusState::rawMonitorFocus(PHLMONITOR pMonitor) {
    if (m_focusMonitor == pMonitor) return;
    ...
    g_pEventManager->postEvent(SHyprIPCEvent{.event = "focusedmon", ...});
```

`focusedmon` fires only when the focused monitor *changes*. On this single-monitor setup
(`eDP-1`) it fires once during startup and never again — this boot's event log confirms
that workspace switches produce `workspace`/`workspacev2`/`activewindow`/`activelayout`
and no `focusedmon`.

**So: if the `j/monitors` snapshot fails or is wiped, and the one `focusedmon` was missed
or came before the event socket connected, the singleton is permanently deaf to workspace
switches with a perfectly healthy `socket2` connection.** This is the mechanism that makes
"never recovers on a workspace switch" true without requiring the event stream to be dead.

## 6. Was the event socket ever plausibly the problem? No.

The map assumed quickshell launches before the compositor's IPC is ready. **Verified in
Hyprland v0.56.1 source**, that is not the case here:

| Step | Where | Stage |
| --- | --- | --- |
| Instance dir `$XDG_RUNTIME_DIR/hypr/$HIS` created | `Compositor.cpp:217-229` (CCompositor ctor) | before any manager |
| `.socket2.sock` bound + `listen()` | `managers/EventManager.cpp:14-41` (CEventManager ctor) | `initManagers(STAGE_PRIORITY)`, `Compositor.cpp:296` |
| `.socket.sock` bound + `listen()` | `debug/HyprCtl.cpp:2321-2346`, called from the CHyprCtl ctor at `:2044` | `initManagers(STAGE_LATE)`, `Compositor.cpp:425` |
| `Event::bus()->m_events.start.emit()` | `render/Renderer.cpp:2029-2033`, guarded `static bool once` | **first rendered frame** |
| legacy `exec-once` dispatched | `config/supplementary/executor/Executor.cpp:23-46`, listener on `start` | after first frame |
| `hl.on("hyprland.start")` dispatched | `config/lua/LuaEventHandler.cpp:165`, listener on the same `start` event | after first frame |

This repo's launch is `hl.exec_cmd("quickshell")` inside
`hl.on("hyprland.start", …)` (`dotfiles/config/hypr/autostart.lua:22,39`), so it goes
through the Lua `start` listener — the exec-once-equivalent path, at the first frame, long
after both sockets are listening.

(Worth knowing for the future: bare top-level `hl.exec_cmd(...)` in a Lua config is *not*
exec-once. `hlExecCmd` calls `executor()->spawn()` immediately
(`config/lua/bindings/LuaBindingsToplevel.cpp:321-335`), which at config-parse time means
during `Config::mgr()->init()` in `STAGE_PRIORITY` — before `.socket.sock` exists. Moving
the quickshell launch out of the `hl.on` block would introduce the very race the map
suspected.)

**Observed locally**, this boot: `Hyprland` started 17:30:31, `quickshell` 17:30:34 — a
three-second gap, and `"Hyprland event socket connected."` appears in the log. The
socket-not-ready hypothesis does not survive.

## 7. A second, independent hazard: truncated request replies

**Verified in source.** `makeRequest`'s response handler reads once, on the first
`readyRead`, and immediately treats what it got as the whole reply:

```cpp
auto responseCallback = [requestSocket, callback]() {
    auto response = requestSocket->readAll();
    callback(true, std::move(response));
    delete requestSocket;
};
```
*(`connection.cpp:179-183`)*

Upstream fixed exactly this bug class for the **event** socket in
[`bd62179`](https://git.outfoxxed.me/quickshell/quickshell/commit/bd62179) — *"Fixes
greetd and hyprland ipc sockets reads being incomplete and breaking said integrations on
slow machines"*, shipped in 0.3.0 and listed in its changelog. That commit introduced
`StreamReader` and applied it to `eventSocketReady` only. **`makeRequest` was not
converted.**

Hyprland writes replies in a loop that can return short writes when the socket buffer
fills (`debug/HyprCtl.cpp:2170-2200`), so a truncated read is possible for large payloads.
A truncated reply parses to a null `QJsonDocument`, hence an **empty array**, hence:

- `refreshMonitors(true)`: `monitorsRequested` is already `true`, then the unconditional
  removal pass deletes **every** monitor → `onFocusedMonitorDestroyed()` nulls
  `bFocusedMonitor` → §5 deafness, with `monitorFor()`'s escape hatch now closed.
- `refreshWorkspaces(true)`: removal pass deletes **every** workspace.

That is total, unrecoverable-from-QML failure from a single short read. **Inference** as to
whether it fires here: `j/monitors` for one 1920x1200 display is roughly a kilobyte and
will not be split; `j/clients` is the plausible victim, and it only affects toplevels. I
rate this a real but secondary candidate versus §3.

## 8. Upstream status

**No upstream issue reports this.** I enumerated all 900 issues in the mirror at
`github.com/quickshell-gh/quickshell` (the `git.outfoxxed.me` tracker 303-redirects there)
and grepped titles and bodies for `exec-once`, `socket2`, `event socket`, `race`,
`reconnect`, `refreshWorkspaces`, `refreshMonitors`, `focusedMonitor` and empty-workspace
phrasings. Nothing matches. The closest neighbours are all the *same class* of
"seeded-once, never recovers" defect, which suggests the pattern is recognised piecemeal
but not as a category:

- **[#795](https://github.com/quickshell-gh/quickshell/issues/795)** (open) — *"The
  Hyprland event socket only emits `activewindowv2` on focus changes, so on shell startup
  `activeToplevel` stays null until the user manually switches focus."* Proposes seeding
  from `j/clients`. Identical shape to §5.
- **[#929](https://github.com/quickshell-gh/quickshell/issues/929)** (open) —
  `changeworkspaceid` (new in Hyprland 0.56.1) is unhandled, so *"`Hyprland.workspaces` …
  go stale after an ID change and never recover on their own"*, and notes
  `refreshWorkspaces()` cannot reconcile it. Same no-recovery property, different trigger.
  Only relevant here if something reassigns workspace IDs, which this config does not.
- **[#837](https://github.com/quickshell-gh/quickshell/issues/837)** (open) —
  `HyprlandMonitor.activeWorkspace` does not update on non-focused monitors. The
  multi-monitor face of the `bFocusedMonitor` gate in §5.
- **[#136](https://github.com/quickshell-gh/quickshell/issues/136)** (open) — titled *"Crash
  on `exec-once`"*, but it is a crash report, unrelated.

**Verified in source:** `git log v0.3.0..origin/master -- src/wayland/hyprland/` contains
exactly one commit (`7d1c9a9`, a toplevel-management reorganisation). **Upstream `master`
as of 2026-08-02 behaves identically to 0.3.0 for everything above.** Nothing is fixed
by upgrading.

## 9. Discriminators for the diagnosis ticket

Cheap tests that separate the candidates, in rough order of value:

1. **Capture a failing boot's log before it is lost.** Logs are under
   `$XDG_RUNTIME_DIR/quickshell/by-id/<id>/` and die with the runtime dir, so copy them
   out. Read with `qs log <file> -r 'quickshell.hyprland*=true'`. Presence of
   `"Hyprland event socket connected."` kills the map's hypothesis outright; presence of
   `"Hyprland ipc status request failed."` or `"Error making request:"` points at the
   request socket; absence of both with an empty workspace model points at §3's stale
   snapshot.
2. **Check `Hyprland.requestSocketPath`** from QML on a failing run. Empty ⇒ constructor
   bailed (§2 rows 1–2). Non-empty ⇒ it did not.
3. **Check `Hyprland.usingLua`** on a failing run. `false` on this Lua-configured machine
   ⇒ the `j/status` round trip failed (§2).
4. **Try `hyprctl reload` on a failing run.** If the dots appear, the event stream is
   alive and the failure is snapshot-side (§3/§7). If they do not, the event socket really
   is dead.
5. **Check whether `Hyprland.focusedMonitor` is null** on a failing run. Null ⇒ §5 explains
   the no-recovery-on-switch symptom without any event-socket failure.

## 10. Consequences for the fix

Stated as constraints the fix has to satisfy, not as a proposed design:

- **A widget-local retry cannot work.** `Hyprland.refreshWorkspaces()` and
  `refreshMonitors()` pass `canCreate = false` and cannot repopulate an emptied model.
  Any retry loop built on them is a no-op. This is the single most important consequence.
- **There is no readiness signal to gate on.** `connected()` is not exposed to QML, and
  there is no `valid`/`ready` property. A readiness gate has to be synthesised — e.g. from
  `Hyprland.focusedMonitor !== null && Hyprland.workspaces.values.length > 0`, or by
  latching on the first `rawEvent`.
- **The recovery primitives that do exist are `Hyprland.monitorFor(screen)` (only before
  the first successful `j/monitors` reply), `Hyprland.refreshToplevels()` (always), and
  `Hyprland.dispatch("reload")`/`hyprctl reload` (always, but heavy-handed — it re-runs
  the whole config).**
- **`monitorFor(screen)` is worth wiring up regardless.** #116 already decided the
  indicator should use per-monitor active workspace rather than the global
  `Hyprland.focusedWorkspace`; `monitorFor` is both the correct per-monitor API and the
  one call that can preemptively create a monitor object. It is a correctness fix and a
  partial startup mitigation at the same time.
- **The failure is shell-wide if it is §5**, exactly as #116 anticipated: a null
  `focusedMonitor` equally breaks `services/Brightness.qml:33,40`,
  `modules/OSD/BrightnessOSD.qml:17`, `modules/notificationPopup/Popups.qml:12` and
  `modules/sessionScreen/SessionScreen.qml:15`.
- **An upstream report is justified** for at least two things: `HyprlandIpcQml::refresh*()`
  passing `canCreate = false` (making the documented recovery API useless against the
  exact state it would be called in), and `makeRequest` not using `StreamReader` after
  `bd62179` converted the event socket. Neither is reported.

## Sources

**Quickshell v0.3.0** (commit `59e9c47`, cloned from `git.outfoxxed.me/quickshell/quickshell`):
`src/wayland/hyprland/ipc/connection.cpp`, `connection.hpp`, `qml.cpp`, `qml.hpp`,
`monitor.cpp`, `workspace.cpp`; commits `ef1a413`, `ae762f5`, `d3b1a65`, `bd62179`;
`changelog/v0.3.0.md`.

**Hyprland v0.56.1** (commit `5c9377c`, `github.com/hyprwm/Hyprland`): `src/Compositor.cpp`,
`src/main.cpp`, `src/managers/EventManager.cpp`, `src/debug/HyprCtl.cpp`,
`src/render/Renderer.cpp`, `src/config/supplementary/executor/Executor.cpp`,
`src/config/lua/LuaEventHandler.cpp`, `src/config/lua/bindings/LuaBindingsToplevel.cpp`,
`src/desktop/state/FocusState.cpp`.

**Docs:** `https://quickshell.org/docs/v0.3.0/types/Quickshell.Hyprland/Hyprland/`.

**Upstream tracker:** `https://github.com/quickshell-gh/quickshell/issues` (all 900 issues
enumerated via the GitHub API on 2026-08-05).

**Local:** `quickshell 0.3.0-2`, `hyprland 0.56.1-3`, Qt 6.11.1; running instance log
`/run/user/1000/quickshell/by-id/uc107lajt/log.qslog` (boot of 2026-08-05 17:30);
`dotfiles/config/hypr/autostart.lua`.
