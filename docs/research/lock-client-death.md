# What happens when the lock client dies — is a hyprlock fallback real?

Research resolution for [#48](https://github.com/bhdai/quickshell_config/issues/48), part of the
lock-screen map [#45](https://github.com/bhdai/quickshell_config/issues/45).

## Verdict up front

**A hyprlock fallback after Quickshell dies is achievable on Hyprland, but only behind an opt-in
config flag that is off by default — and turning that flag on breaks the lock's security model.**

The source HLD's claim that "another ordinary locker generally cannot simply take over" is
**half right, for the wrong reason**. It is not a protocol limitation and it is not
"generally" true. The `ext-session-lock-v1` spec explicitly *permits* takeover and leaves it to
compositor policy. Hyprland implements exactly that policy as
`misc:allow_session_lock_restore`, default `false`. With the default, hyprlock is denied and
exits immediately — the fallback is dead. With the flag flipped, hyprlock takes over fine.

**Do not flip the flag.** Reading Hyprland's source, `allow_session_lock_restore = true` also
lets any client take over a *live* lock and unlock it without authenticating (see
[Security cost](#the-security-cost-of-allow_session_lock_restore)). That violates the map's
"lock must fail closed" requirement.

**The answer is therefore not fallback.** It is:

1. **Recovery** — Hyprland already ships a first-class, compositor-native recovery for exactly
   this situation (`hl.clear_crashed_lockscreen()`), and prints the instructions on screen. This
   needs to be **documented, not engineered around**.
2. **Supervision** — a systemd user unit with `Restart=always`, which is worth specifying but
   whose benefit is narrower than it first appears (see [Q6](#q6-supervision)).

Version-pinned to what is installed on this machine: Hyprland 0.56.0 (commit `36b2e0cf`),
hyprlock 0.9.6, hypridle 0.1.7, Quickshell 0.3.0, wayland-protocols 1.49.

---

## Q1. What `ext-session-lock-v1` mandates on client death

Source: `/usr/share/wayland-protocols/staging/ext-session-lock/ext-session-lock-v1.xml`
(wayland-protocols 1.49, installed locally), interface `ext_session_lock_v1`. RFC-2119 keywords
are normative here — the protocol says so explicitly.

Three clauses matter, quoted verbatim:

> If the client dies while the session is locked, the compositor **must not** unlock the session
> in response. It is acceptable for the session to be permanently locked if this happens.

> The compositor **may** choose to continue to display the lock surfaces the client had mapped
> before it died or alternatively fall back to a solid color, this is compositor policy.

> Compositors **may** also allow a secure way to recover the session, the details of this are
> compositor policy. Compositors **may** allow a new client to create a `ext_session_lock_v1`
> object and take responsibility for unlocking the session, they **may** even start a new lock
> client instance automatically.

And from `ext_session_lock_surface_v1.destroy`:

> If a lock surface on an active output is destroyed before the
> `ext_session_lock_v1.unlock_and_destroy` event is sent, the compositor **must** fall back to
> rendering a solid color.

**So:** staying locked is mandatory. What is displayed is compositor policy. And crucially —
**takeover by a new client is explicitly permitted by the protocol.** The HLD framing that a
second locker "generally cannot" take over is not a protocol fact. It is a per-compositor fact,
and it has to be checked against Hyprland's code, which is what Q2 does.

One more protocol detail that becomes relevant in Q5: `ext_session_lock_v1.destroy` is a
**protocol error** (`invalid_destroy`) if the `locked` event was already sent — a client
tearing down a held lock must use `unlock_and_destroy`.

---

## Q2. What Hyprland actually does

All line references are Hyprland `v0.56.0`.

### The lock survives client death

In [`src/protocols/SessionLock.cpp`](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/protocols/SessionLock.cpp),
`CSessionLockProtocol::m_locked` is set `true` in `onLock` (L200) and is cleared in only two
places: the client's own `unlock_and_destroy` handler (L128) and `forceUnlock()` (L243).

Client death runs `setOnDestroy` → `destroyResource(this)` (L111, L177), which erases the lock
resource **without touching `m_locked`**. `isLocked()` (L238) therefore keeps returning `true`.
Hyprland conforms: the session stays locked.

Separately, `CSessionLockManager`'s `listeners.destroy` resets `m_sessionLock` to null
([`SessionLockManager.cpp`](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/managers/SessionLockManager.cpp) L90-96).
So after a crash the compositor is in the state `isLocked() == true, m_sessionLock == nullptr` —
locked, with no owner. This is the "lockdead" state.

### What is displayed — not a solid color

The HLD says "Hyprland remains locked with fallback color". That is **wrong for Hyprland**. It
renders a black primer and then a full-screen instructional image
([`Renderer.cpp`](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/render/Renderer.cpp)
L1644-1654, `renderSessionLockMissing` L1685-1712), after `misc:lockdead_screen_delay`
(default 1000 ms, confirmed live via `hyprctl getoption`).

The shipped asset `/usr/share/hypr/lockdead.png` reads, verbatim:

> Oopsie daisy, it looks like you locked your screen but the lockscreen app died :(
>
> If you want to unlock your screen, go into another tty (e.g. ctrl+alt+F3), log in, and run:
> `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`
>
> if that doesn't help, try killing any existing processes of your lock, e.g.
> `killall -9 hyprlock`
> then run the eval command again.
>
> Once you unlock your session, press CTRL+D (or run exit) in the tty you were to log out,
> then come back here.
>
> You can come back to Hyprland with ctrl+alt+F[N] where N is the tty number in the top left corner.

Hyprland also renders the live TTY number in the corner (`Renderer.cpp` L1626, `"Running on tty {}"`).
`lockdead2.png` — used when lock surfaces are still mapped but the lock is otherwise
considered missing — is just a dim logo with no instructions.

**This is the single most important practical finding: the user is not stranded and is not
staring at a blank color. Hyprland tells them, on screen, exactly how to recover.**

### Can a second client bind the protocol afterwards? Yes — gated

`SessionLockManager.cpp` L52-63:

```cpp
static auto PALLOWRELOCK = CConfigValue<Config::INTEGER>("misc:allow_session_lock_restore");

if (PROTO::sessionLock->isLocked() && !*PALLOWRELOCK && g_pCompositor->m_startLockedCommand.empty()) {
    LOGM(Log::DEBUG, "Cannot re-lock, misc:allow_session_lock_restore is disabled");
    pLock->sendDenied();
    return;
}

if (m_sessionLock && !clientDenied() && !clientLocked())
    return; // Not allowing to relock in case the old lock is still in a limbo
```

`sendDenied()` sets the lock inert and sends `finished`.

Because the crash path already nulled `m_sessionLock`, the second guard is not hit. So the
outcome is decided entirely by `misc:allow_session_lock_restore`:

| `misc:allow_session_lock_restore` | New lock client after a crash |
| --- | --- |
| `false` (default) | Denied — `finished` sent immediately |
| `true` | Allowed — becomes the new lock owner and can unlock |

Confirmed on this machine: `hyprctl getoption misc:allow_session_lock_restore` → `bool: false,
set: false` (default, not set in `~/.config/hypr`).

Official wiki
([`content/Configuring/Basics/Variables.md`](https://github.com/hyprwm/hyprland-wiki/blob/main/content/Configuring/Basics/Variables.md)):

> `allow_session_lock_restore` — if true, will allow you to restart a lockscreen app in case it
> crashes — bool — `false`

Practitioner corroboration (Tier B): Hyprland issue
[#13844](https://github.com/hyprwm/Hyprland/issues/13844) ("hypelock crashing") — the answer
given to the reporter is exactly `misc { allow_session_lock_restore = 1 }`.

### There is also a compositor-native recovery

[`src/config/lua/bindings/LuaBindingsToplevel.cpp`](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/config/lua/bindings/LuaBindingsToplevel.cpp)
L337-350:

```cpp
static int hlClearCrashedLockscreen(lua_State* L) {
    if (!g_pSessionLockManager)
        return Internal::configError(L, "hl.clear_crashed_lockscreen: sessionLockMgr not init'd yet");
    if (!g_pSessionLockManager->isSessionLocked())
        return Internal::configError(L, "hl.clear_crashed_lockscreen: session is not locked");
    if (g_pSessionLockManager->clientLocked() || g_pSessionLockManager->clientDenied())
        return Internal::configError(L, "hl.clear_crashed_lockscreen: session is locked with a client, refusing to unlock");
    g_pSessionLockManager->forceUnlock();
    return 0;
}
```

Added by commit `87604a7e` (2026-07-02, PR
[#15299](https://github.com/hyprwm/Hyprland/pull/15299), "config/lua: add
hl.clear_crashed_lockscreen() and fix tty instructions"), present in 0.56.0. The PR rationale:
"Considering only your user has access to the IPC socket, this should be totally fine."

**The guard is the good part.** It refuses when `clientLocked()` — i.e. when a live client holds
the lock. It can only clear an *ownerless* lock. It is not a lock bypass.

---

## Q3. Can hyprlock take over? — plain verdict

**With the default config: no. Flatly no.**

Hyprland denies the lock request (`sendDenied()` → `finished`), and hyprlock does not retry.
[`hyprlock v0.9.6 src/core/hyprlock.cpp`](https://github.com/hyprwm/hyprlock/blob/v0.9.6/src/core/hyprlock.cpp)
L828-847:

```cpp
void CHyprlock::onLockFinished() {
    Log::logger->log(Log::INFO, "onLockFinished called. Seems we got yeeten. Is another lockscreen running?");
    ...
    m_bTerminate = true;
}
```

It logs and exits. So `hypridle`'s existing `lock_cmd = pidof hyprlock || hyprlock` is **not** a
safety net after Quickshell dies holding the lock — it spawns a hyprlock that dies in
milliseconds, leaving the lockdead screen exactly as it was.

**With `misc:allow_session_lock_restore = true`: yes, genuinely.** hyprlock would be allowed
through `onNewSessionLock`, map its surfaces, authenticate via PAM, and `unlock_and_destroy`. The
fallback works. The HLD's "generally cannot simply take over" does not hold for Hyprland with
that flag set.

### The security cost of `allow_session_lock_restore`

*(Read from source; reasoned, not empirically exploited.)*

Look again at the two guards. When `allow_session_lock_restore` is true and a **live, healthy**
lock client holds the session:

- Guard 1 is skipped (`!*PALLOWRELOCK` is false).
- Guard 2 is `if (m_sessionLock && !clientDenied() && !clientLocked()) return;` — with a live
  locked client, `clientLocked()` is **true**, so `!clientLocked()` is false, the whole condition
  is false, and it does **not** return.

So control falls through and `m_sessionLock` is **replaced** by the new client. That new lock
object is not inert, so its `unlock_and_destroy` handler (`SessionLock.cpp` L122-140) runs
`PROTO::sessionLock->m_locked = false` — Hyprland does not verify that `locked` was ever sent to
that client before honouring it.

Net effect: **with the flag on, any process running as the user can lock-then-unlock to clear an
active lock screen without authenticating.** Since `ext-session-lock-v1` is exposed to all
clients on Hyprland (`bindManager` has no privilege check), that is any program the user runs —
including anything that got in via a browser exploit or a malicious dependency.

For a lock screen whose stated requirement is "must fail closed", this trade is not worth taking
to buy a fallback for a rare crash. **Recommend: leave `misc:allow_session_lock_restore` at its
default `false`.**

---

## Q4. Recovery paths that actually exist

Ranked by what to reach for first. All should be **documented for the user, not engineered
around** — Hyprland already does the engineering.

### 1. The intended path: TTY + clear the crashed lock

Hyprland prints this on the lockdead screen itself. Press `Ctrl+Alt+F3` (any free TTY; the
current one is shown in the corner, `tty1` on this machine), log in, then:

```sh
hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
```

**Verified on this machine.** Executed live while unlocked, it reaches the real guard and returns
the exact error string from `LuaBindingsToplevel.cpp` L342:

```
error: return hl.clear_crashed_lockscreen();:1: hl.clear_crashed_lockscreen: session is not locked
```

A bogus name (`hl.this_does_not_exist()`) returns `attempt to call a nil value`, which confirms
the function really is bound and reachable — not silently swallowed.

Critically, **it also works with no Hyprland environment at all** — no
`HYPRLAND_INSTANCE_SIGNATURE`, no `WAYLAND_DISPLAY`, no `XDG_RUNTIME_DIR`. That was tested
explicitly by unsetting all three; `--instance 0` does the discovery. This is what makes it
usable from a bare TTY login or SSH.

Then return to the session with `Ctrl+Alt+F1` (the TTY number Hyprland renders in the corner).

> Note: `hyprctl dispatch 'hl.clear_crashed_lockscreen()'` also reaches the function but then
> emits a spurious second error (`hl.dispatch: expected a dispatcher`). Use `eval`, as the
> lockdead screen says.

This path requires the Hyprland config to be Lua. **This machine already is** — `~/.config/hypr/`
is `hyprland.lua`, `binds.lua`, `autostart.lua`, etc., and `hypridle.conf` already calls
`hyprctl dispatch 'hl.dsp.dpms(...)'`. No migration needed.

### 2. SSH instead of a TTY

Identical command. Because it needs no session environment, plain `ssh user@host` then the same
one-liner works. Useful if the machine is reachable from a phone or another laptop.

### 3. If a stale lock process is still around

Per the lockdead screen, if step 1 reports the session is locked *with* a client, some lock
process is still alive and holding it:

```sh
killall -9 quickshell    # or: killall -9 hyprlock
hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
```

### 4. `loginctl unlock-session` — does **not** work

Do not document this as a recovery path; it is a trap.

Hyprland has no logind lock/unlock integration at all — searching the v0.56.0 tree for
`LockSession`/`lock-session` handling turns up nothing. The bridge is `hypridle`, which listens
for the logind `Lock`/`Unlock` D-Bus signals and shells out to `lock_cmd` / `unlock_cmd`
([`hypridle src/core/Hypridle.cpp`](https://github.com/hyprwm/hypridle/blob/main/src/core/Hypridle.cpp),
`handleDbusLogin`).

Two independent reasons it fails here:

- This machine's `~/.config/hypr/hypridle.conf` defines **no `unlock_cmd`**, so the signal
  triggers nothing at all.
- Even with one, no external command can clear a compositor-held `ext-session-lock`. Only the
  owning client (dead) or the compositor (`forceUnlock`) can. `loginctl unlock-session` would
  flip `LockedHint` and change nothing on screen.

### 5. Last resort

`loginctl terminate-session <id>` or `systemctl restart display-manager` — kills the Hyprland
session and loses unsaved work. Mention only as the final fallback.

### Recommendation

Add a short "if the lock screen crashes" section to the repo's docs with the command from path 1
verbatim. That is the entire engineering cost. Hyprland already displays it on the screen the
user will be looking at.

---

## Q5. The hot-reload interaction

**Short answer: a QML error while the lock is held does *not* count as client death, and does
*not* strand the session. Developing the lock screen is safe from the ordinary edit-save loop.**
There are two narrower ways to lose the session, listed below.

> Overlaps with research ticket #46 (API semantics). Established here independently from
> Quickshell v0.3.0 source; #46 should be consulted for the `locked`/`secure` state machine
> rather than this document.

### A QML error keeps the old, working generation alive

[`src/core/rootwrapper.cpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/core/rootwrapper.cpp)
`reloadGraph()` handles both failure modes — scanner errors (L74-96) and a component that fails
to become ready (L106-145) — the same way: log "Failed to load configuration", `destroy()` the
**new** generation, emit `reloadFailed`, spawn the reload popup, and `return` **without ever
assigning `this->generation`**.

The old generation — including the live `WlSessionLock`, its `SessionLockManager`, and the
`ext_session_lock_v1` Wayland object — is never touched. The process does not exit, the Wayland
connection is not dropped, the compositor sees nothing. The lock keeps working; the screen keeps
showing the last good lock surface.

This is the common case: a typo, a missing import, a bad binding target. **Safe.**

### A *successful* reload deliberately carries the lock across

[`src/wayland/session_lock.cpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/wayland/session_lock.cpp)
L24-33:

```cpp
void WlSessionLock::onReload(QObject* oldInstance) {
    auto* old = qobject_cast<WlSessionLock*>(oldInstance);
    if (old != nullptr) {
        QObject::disconnect(old->manager, nullptr, old, nullptr);
        this->manager = old->manager;          // adopt the live lock
        this->manager->setParent(this);
    } else {
        this->manager = new SessionLockManager(this);
    }
    ...
}
```

The new `WlSessionLock` **adopts the old instance's `SessionLockManager`**, which owns the
Wayland lock object. The lock is never released and never re-acquired — no window of exposure,
no re-authentication. This is deliberate and it works. **Safe.**

### Failure mode 1: the old instance is not matched

The adoption above depends entirely on `oldInstance` being non-null. Matching rules, from
[`src/core/reload.cpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/core/reload.cpp):

- `Reloadable::reloadRecursive` (L92-106) only looks up an old instance
  **if `reloadableId` is non-empty** — and `reloadableId` has no default; it is a plain
  `Q_PROPERTY(QString reloadableId MEMBER mReloadableId)` you must set yourself
  ([`reload.hpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/core/reload.hpp) L49).
- `ReloadPropagator::onReload` (L57-71) instead matches children **by list index**.
- `ShellRoot` **is** a `ReloadPropagator`
  ([`shell.hpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/core/shell.hpp)).

So a `WlSessionLock` declared as a direct child of `ShellRoot` in `shell.qml` is matched by
position, with no `reloadableId` needed. But **adding, removing, or reordering a sibling before
it in `shell.qml` shifts the index**, `qobject_cast<WlSessionLock*>` on the wrong old child
returns null, and the new lock builds a fresh `SessionLockManager` while the old one is
destroyed with the old generation.

That destructor is
[`session_lock/lock.cpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/wayland/session_lock/lock.cpp)
L16-21:

```cpp
QSWaylandSessionLock::~QSWaylandSessionLock() {
    if (this->isInitialized()) {
        // This will intentionally lock the session if the lock is destroyed without calling unlock.
        this->destroy();
    }
}
```

It sends the plain `destroy` request. Per the protocol that is an `invalid_destroy` **protocol
error** once `locked` has been sent — on a strict compositor (sway/wlroots) that kills the client
connection outright. **Hyprland does not enforce it**: its `setDestroy` handler
(`SessionLock.cpp` L110-111) has no locked-state guard and simply erases the resource. So on this
machine the outcome is not a crash but the lockdead state — locked, ownerless, `m_locked` still
true. The new `SessionLockManager` in the reloaded generation would then be denied if it tried to
lock (default config).

**Mitigation, cheap and worth specifying: set an explicit `reloadableId` on the `WlSessionLock`.**
That replaces fragile index matching with name matching and makes the lock survive arbitrary
reshuffling of `shell.qml`.

Note the same index-matching hazard applies if the lock is nested under a non-`Reloadable`
wrapper: `ReloadPropagator::onReload`'s `else` branch calls
`Reloadable::reloadRecursive(newChild, ...)` with a `newChild` already known to be null, which is
a no-op — such subtrees are not traversed at all. Declaring the lock directly under `ShellRoot`,
with a `reloadableId`, avoids this entirely.

### Failure mode 2: `qFatal()` — genuine process abort

`session_lock.cpp` contains hard aborts that **do** kill the process and produce true client death:

- L102 — `qFatal() << "Tried to show lockscreen surfaces without active lock"`
- L253 — `qFatal() << "Failed to attach WlSessionLockSurface"`
- L256 — `qFatal() << "Tried to attach a WlSessionLockSurface whose parent is not a WlSessionLock"`
- `session_lock/session_lock.cpp` L72 — `qFatal() << "Cannot change the attached window of a LockWindowExtension"`

These are reachable from ordinary QML mistakes (a `surface` component that does not produce a
`WlSessionLockSurface`, a lock/surface lifecycle race). Unlike a parse error, these take the whole
shell down and wedge the session. Testing the lock module **should be done in a nested/second
instance**, per `AGENTS.md`'s dev-clone workflow, rather than against the live shell.

### Practical guidance for the build phase

Editing lock QML while locked is safe for errors, safe for successful reloads, and risky only
around `shell.qml` structural edits and `qFatal` paths. Combined with the Q4 recovery command
being a single TTY one-liner, this is a manageable risk — not a reason to avoid hot reload.

---

## Q6. Supervision

### What exists today

Quickshell is started fire-and-forget from `~/.config/hypr/autostart.lua` L39:

```lua
hl.exec_cmd("sleep 3 && quickshell")
```

- **Hyprland has no respawn.** `hl.exec_cmd`'s optional second argument is a **window-rule**
  table (`float`, `workspace`, …) built by `Internal::buildRuleFromTable`
  ([`LuaBindingsInternal.cpp`](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/config/lua/bindings/LuaBindingsInternal.cpp) L509+),
  not a supervision spec. There is no keepalive/restart option anywhere in Hyprland's exec.
- **Quickshell ships no systemd unit.** Confirmed via `pacman -Ql quickshell` — QML modules only.
  By contrast `hypridle`, `hyprpaper`, `hyprsunset` and `xdg-desktop-portal-hyprland` all ship
  user units.

### The important caveat: restarting does not un-wedge the session

A `Restart=always` unit gets the bar, launcher and OSD back. It does **not** clear the lock:

- Hyprland still has `m_locked == true` with no owner.
- The restarted Quickshell has a process-local view only —
  `QSWaylandSessionLockManager::isLocked()` is literally `this->active != nullptr`
  ([`session_lock/manager.cpp`](https://github.com/quickshell-mirror/quickshell/blob/v0.3.0/src/wayland/session_lock/manager.cpp)),
  so a fresh instance has no way to know the session is already locked.
- If it did try to lock, Hyprland denies it (default config) →
  `ext_session_lock_v1_finished()` → `unlock()` → `unlocked` signal → `WlSessionLock::unlock` →
  `locked` silently returns to `false`. Quickshell gives up quietly and `secure` never becomes
  true. (That is correct fail-closed behaviour, and it satisfies the HLD's "another session
  locker owns the protocol → do not claim securely locked" row.)

So supervision **is not a substitute for the Q4 recovery command**, and it is not a fallback
mechanism. It is worth doing for a different reason: today, *any* Quickshell crash — bar, OSD,
launcher, nothing to do with the lock — leaves the user with no shell until they manually
restart it.

### Recommendation

Specify a systemd user unit, with modest expectations:

```ini
[Unit]
Description=Quickshell
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/quickshell
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
```

Two caveats found while checking feasibility:

1. **`hyprland-session.target` does not exist on this machine.** `autostart.lua` L31 runs
   `systemctl --user start hyprland-session.target`, but `systemctl --user cat
   hyprland-session.target` returns "No files found", and `graphical-session.target` is
   currently `inactive`. So that line is failing silently today and the portal chain it was
   meant to enable is not coming up either. **A unit that binds to either target will not start
   until this is fixed** — this is a pre-existing bug adjacent to this ticket, worth its own
   issue rather than being fixed inside the lock work.
2. Moving Quickshell to systemd means dropping the `hl.exec_cmd("sleep 3 && quickshell")` line,
   and the `sleep 3` ordering hack should become a proper `After=` dependency.

**Verdict on supervision: worth specifying, but as general shell resilience, not as lock-crash
mitigation.** Rank it below documenting the recovery command, and gate it on fixing the session
target. Do not let it justify enabling `allow_session_lock_restore`.

---

## Corrections to the source HLD (section 8)

| HLD row | Finding |
| --- | --- |
| "Quickshell crash after secure lock → Hyprland remains locked with **fallback color**" | Stays locked ✅, but Hyprland renders `lockdead.png` with recovery instructions and the TTY number, not a solid color. |
| "A fallback locker only helps before Quickshell acquires the session lock" | True **only under the default config**. It is a Hyprland policy flag (`misc:allow_session_lock_restore`), not a protocol limit. |
| "another ordinary locker **generally cannot** simply take over" | Misleading. The protocol explicitly permits takeover; Hyprland implements it. It is off by default and should stay off — for security reasons the HLD does not mention. |
| "Recovery is compositor policy" | Correct, and Hyprland's policy is concrete and good: `hl.clear_crashed_lockscreen()`, guarded so it cannot clear a live lock. |
| "avoiding live QML reloads while locked are important" | Overstated. Reloads are explicitly handled — errors keep the old generation, successful reloads hand the lock over. The real hazards are `shell.qml` index shifts (fix with `reloadableId`) and `qFatal` paths. |
| "IPC unavailable → Hypridle may launch a separately configured fallback locker" | Only helps *before* the lock is taken. After a crash, `lock_cmd` spawns a hyprlock that is denied and exits immediately. |

---

## Confidence and limits

**Empirically verified on this machine:** `misc:allow_session_lock_restore` exists and is `false`;
`misc:lockdead_screen_delay` is `1000`; `hl.clear_crashed_lockscreen()` is bound and reachable via
`hyprctl --instance 0 eval` with zero environment variables, returning the real guard error;
`lockdead.png` contents; the Hyprland config is Lua; no Quickshell systemd unit;
`hyprland-session.target` missing and `graphical-session.target` inactive.

**Read from source, not executed:** everything about the crash path itself. I did not kill a lock
client holding a live lock — doing so on this machine would have stranded the user's session,
which is precisely the failure under study. The `m_locked` / `m_sessionLock` state transitions,
hyprlock's exit-on-`finished`, Quickshell's reload handover, and the
`allow_session_lock_restore` privilege-escalation analysis are all read directly from the pinned
source of the exact installed versions.

**Flagged as inference:** the claim that `allow_session_lock_restore = true` permits an
unauthenticated bypass of a *live* lock. It follows directly from the two guards in
`onNewSessionLock` plus the unchecked `unlock_and_destroy` handler, but I did not write a client
to demonstrate it. It is a strong enough reading to justify leaving the flag off; if the project
ever wants the flag on, demonstrate or refute this first.

## Sources

- `ext-session-lock-v1.xml`, wayland-protocols 1.49, local: `/usr/share/wayland-protocols/staging/ext-session-lock/`
- Hyprland v0.56.0 — `src/protocols/SessionLock.cpp`, `src/managers/SessionLockManager.{cpp,hpp}`, `src/render/Renderer.cpp`, `src/config/lua/bindings/LuaBindingsToplevel.cpp`, `src/Compositor.cpp`, `src/main.cpp`
- Hyprland wiki — `content/Configuring/Basics/Variables.md`
- Hyprland PR [#15299](https://github.com/hyprwm/Hyprland/pull/15299), issue [#13844](https://github.com/hyprwm/Hyprland/issues/13844)
- hyprlock v0.9.6 — `src/core/hyprlock.cpp`
- hypridle — `src/core/Hypridle.cpp`
- Quickshell v0.3.0 — `src/wayland/session_lock.{cpp,hpp}`, `src/wayland/session_lock/{lock,manager,session_lock}.cpp`, `src/core/{reload.cpp,reload.hpp,rootwrapper.cpp,shell.hpp}`
- Local: `/usr/share/hypr/lockdead.png`, `/usr/share/hypr/lockdead2.png`, `~/.config/hypr/*`
