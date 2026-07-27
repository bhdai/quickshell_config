# WlSessionLock and PamContext semantics — Quickshell 0.3.0

Resolves issue #46 (part of map #45). Supersedes **sections 2 and 3** of the source HLD
(`/tmp/lock-screen-quickshell.md`).

## Provenance and confidence

Every claim below is tagged:

- **[source]** — read in the Quickshell C++ implementation at the exact `v0.3.0` tag.
- **[documented]** — stated in the published v0.3.0 docs or an in-source doc comment.
- **[protocol]** — stated in the `ext-session-lock-v1` protocol specification.
- **[inferred]** — a consequence I derived from the above but did **not** observe running.
  Every inference names the experiment that would settle it.

Source read: `git.outfoxxed.me/quickshell/quickshell`, signed tag `v0.3.0`, commit
`59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83` ("version: 0.3.0"), matching the installed
Arch package `quickshell 0.3.0-2`. Files: `src/wayland/session_lock.{hpp,cpp}`,
`src/wayland/session_lock/{session_lock,manager,lock}.{hpp,cpp}`,
`src/core/{reload,generation,shell}.{hpp,cpp}`,
`src/services/pam/{qml,conversation,subprocess}.{hpp,cpp}`.

Docs and protocol triangulated against the source; they agree except where noted in Q1.

---

## Q1 — `locked` binding vs `unlock()`: which is the unlock path, and do they conflict?

**Verdict: bind `locked`. Never call `unlock()`. It is not public API.**

`unlock()` is declared under `private slots:` in `session_lock.hpp:93` **[source]**. It is
reachable from QML only because Qt places every slot in the metaobject regardless of C++
access. The proof that this is leakage rather than API: the installed
`quickshell-wayland.qmltypes` lists both `Method { name: "unlock" }` **and**
`Method { name: "onScreensChanged" }` — the latter is unambiguously an internal screen-hotplug
handler. It has no doc comment, and it appears nowhere in the published docs. The documented
unlock path is `lock.locked = false` **[documented]** — stated in the class doc comment
(`session_lock.hpp:39`) and on the docs page.

**Do they conflict? Yes, in two distinct ways.**

1. **Calling `unlock()` under a binding desynchronises state without breaking the binding.**
   `unlock()` sets `lockTarget = false`, tears down the compositor lock, deletes the surfaces
   and emits `lockStateChanged` (`session_lock.cpp:138-151`) **[source]**. A QML binding
   re-evaluates only when one of *its own dependencies* changes — not when the target
   property's notify signal fires. So after `unlock()`, `locked` reads `false` while the
   binding expression still evaluates `true`. The declared intent and the real state diverge
   silently. **[inferred, standard QML binding semantics]**

2. **An imperative `lock.locked = false` from QML permanently destroys the binding.** This is
   ordinary QML semantics, and it is exactly what the upstream doc example does
   (`onClicked: lock.locked = false`). If the HLD's `locked: controller.lockRequested` binding
   coexists with any imperative write anywhere in the tree, the binding is gone after the first
   write and no subsequent `lockRequested` change will ever lock again. **[inferred, standard
   QML binding semantics]**

**HLD verdict on this point: the HLD is RIGHT.** `locked: controller.lockRequested` is the
correct construction, and the HLD's rule "LockView must not be able to directly set
`locked = false`" is correct and load-bearing — not stylistic. The one thing the HLD does not
say, and must: **the upstream documentation's own example is unsafe for this design.** Copying
`onClicked: lock.locked = false` into a tree that also binds `locked` silently breaks locking.

### Additional finding the HLD does not cover: `locked` can go false on its own

The compositor can send `ext_session_lock_v1::finished` — it "might be sent because there is
already another ext_session_lock_v1 object held by a client", or because the compositor denies
the request **[protocol]**. Quickshell wires that event to
`QSWaylandSessionLock::ext_session_lock_v1_finished()` → `unlock()` → `SessionLockManager::unlocked`
→ `WlSessionLock::unlock()` (`session_lock.cpp:39`, `lock.cpp:44-48`) **[source]**.

So `locked` can transition to `false` with nothing in QML having asked. Because of conflict (1)
above, the binding will still read `true` and **nothing retries**. The controller must therefore
treat `onLockedChanged` as an input, not only an output, and reconcile:

- `locked` went false while the controller still wants a lock → the lock was **denied**. Fail
  closed: this is not an authenticated unlock, and the shell must not report a secure state.

---

## Q2 — `secure` timing and what it guarantees

**Verdict: the HLD is RIGHT. `locked` and `secure` are genuinely distinct observable states.**

- `locked` reads `manager->isLocked()`, which is true as soon as the lock object is acquired —
  i.e. as soon as the *request* is sent (`session_lock.cpp:159-161`, `manager.cpp:14-20`)
  **[source]**.
- `secure` reads `SessionLockManager::isSecure()` → `active->hasCompositorLock()`, set true only
  in `ext_session_lock_v1_locked()` (`lock.cpp:39-42`, `manager.cpp:21-23`) **[source]**.

The `locked` event is the compositor's confirmation, and the protocol is explicit about its
strength: it cannot be sent until "a new 'locked' frame has been presented on all outputs and no
security sensitive normal/unlocked content is possibly visible", and the compositor "must stop
rendering and providing input to normal clients" **[protocol]**. The docs restate it: "set to
true once the compositor has confirmed all screens are covered with locks" **[documented]**.

So `secure == true` is a real guarantee that no unlocked content is visible on any output. The
HLD's rule — *do not report "screen securely locked" merely because `locked` was set to true* —
is correct, and this is the property that suspend-on-lock must gate on.

**Caveat the HLD should record:** `secure` is derived from a **process-global** static manager,
not from the individual `WlSessionLock` instance (`SessionLockManager::isSecure()` is a static
reading a file-scope singleton, `session_lock.cpp:50`, `session_lock/session_lock.cpp:13-23`)
**[source]**. With exactly one `WlSessionLock` in the process this is correct. With two, both
would report `secure == true` when either is secure. Keep the invariant: **exactly one
`WlSessionLock` in the whole shell.**

---

## Q3 — Hot reload while locked

**This is the finding that matters most for this repo, and the HLD is wrong about it.**

**Verdict: Quickshell *attempts* to preserve the lock across reload, but preservation is
conditional and the failure modes are severe — ranging from silently unlocking the session to
locking you out of the machine entirely.**

### The reload order

`EngineGeneration::onReload` reloads the **new** tree first and destroys the old generation
**after** (`generation.cpp:144-157`) **[source]**. So during the new `WlSessionLock::onReload`,
the old instance and its live compositor lock are still alive.

### Preservation is conditional on old-instance matching

`WlSessionLock::onReload(oldInstance)` adopts the previous manager — and therefore the live
compositor lock — but only `if (old != nullptr)`; otherwise it constructs a fresh
`SessionLockManager` (`session_lock.cpp:24-33`) **[source]**.

Whether `oldInstance` is non-null depends entirely on tree position (`reload.cpp:57-71, 92-106`)
**[source]**:

- `ShellRoot` is a `ReloadPropagator` (`shell.hpp:12`), which matches children **by index**. A
  `WlSessionLock` declared as a direct child of `ShellRoot` is matched automatically — *as long
  as its index does not move.*
- Anywhere else (nested inside a plain `QtObject`/`Item` wrapper — e.g. the HLD's
  `LockModule.qml`), matching requires an explicit **`reloadableId`**. Without it,
  `oldInstance == nullptr`.

This repo currently sets `reloadableId` in exactly one place (`services/Brightness.qml:46`), and
`shell.qml` declares five positional children of `ShellRoot`. **Inserting a widget above the lock
module in `shell.qml` would shift its index and break matching** — a routine edit becomes a
security event.

### The four outcomes

Let `wantLock` be the value the new generation's binding puts into `locked` before `onReload`
runs.

| Old instance matched? | `wantLock` | Outcome |
|---|---|---|
| Yes | `true` | **Lock preserved.** `manager->lock()` returns false (already locked), so `lockTarget` is reset to false, but `updateSurfaces(true, old)` finds the manager locked and proceeds. **[source]** |
| Yes | `false` | **SESSION UNLOCKS.** `realizeLockTarget` takes the else branch → `unlock()` → `unlock_and_destroy`. The screen opens. **[source]** |
| No | `true` | **Process aborts (`qFatal`), session left locked with no client.** See below. **[source + inferred]** |
| No | `false` | **Session left locked with no client.** Old manager destroyed without unlocking. See below. **[source]** |

**Row 2 is the catastrophic one for a hot-reloading repo.** `realizeLockTarget` reads
`this->lockTarget`, which belongs to the *new* object. If the lock state lives in an ordinary
QML controller, the new generation's controller starts at its default — unlocked — the binding
writes `false`, and the reload **unlocks a locked screen**. Note the write is a no-op at binding
time (`setLocked` early-returns because `manager == nullptr` makes `isLocked()` read
`lockTarget`, already `false`, `session_lock.cpp:167-177`), so nothing warns; the unlock happens
later inside `onReload`. **Saving a file would open your locked laptop.** **[source]**

**Row 3:** `SessionLockManager::lock()` returns false when `sessionLocked()` is true — and the
old generation's lock is still alive at that moment (`session_lock/session_lock.cpp:27-28`).
`realizeLockTarget` sets `lockTarget = false` but then calls `updateSurfaces(true, old)`
**unconditionally**, which begins `if (!this->manager->isLocked()) qFatal() << "Tried to show
lockscreen surfaces without active lock"` (`session_lock.cpp:100-102, 130-132`) **[source]**.
That is a hard process abort, not a graceful failure.

**Rows 3 and 4 both end in lockout.** `SessionLockManager` has no destructor, so the
`QSWaylandSessionLock` child is destructed, and `~QSWaylandSessionLock` calls the raw wayland
`destroy()` rather than `unlock_and_destroy()` — with the in-source comment "This will
intentionally lock the session if the lock is destroyed without calling unlock"
(`lock.cpp:16-21`) **[source]**. The protocol is blunt about what this means: after the `locked`
event, "making the destroy request is a protocol error" **[protocol]**, and a client that dies
while locked must not cause the compositor to unlock. The result is a session locked by a
compositor with **no client left to authenticate against** — recoverable only from a TTY.
**[inferred from source + protocol]**

**This also contradicts the docs' own claim** that attempting to lock while another lock is
active "will do nothing" **[documented]**. In the same-process case it does not do nothing; it
`qFatal`s. **[source]**

### A further defect worth knowing about

`realizeLockTarget` calls `updateSurfaces(false)` — with the default `old = nullptr` — *before*
`updateSurfaces(true, old)` (`session_lock.cpp:128-132`) **[source]**. The first call already
populates `this->surfaces` for every screen, so the second call's
`if (!this->surfaces.contains(screen))` guard never fires and the `old` argument is never used.
The window-adoption path in `WlSessionLockSurface::onReload` (which adopts the previous
`QQuickWindow` via `disownWindow()`) is therefore effectively unreachable on a locked reload.
Since the old surfaces are still alive at that point and the protocol makes a second lock surface
for the same output a `duplicate_output` protocol error **[protocol]**, a matched reload may
additionally trip a protocol error. I did **not** confirm this empirically — it is **[inferred]**.

### What the HLD says, and what to do

The HLD's checklist item — *"QML reload/restart is disabled or carefully controlled while
locked"* — is **directionally right but far too weak, and it is unimplementable as written**:
Quickshell gives QML no way to refuse a reload. Replace it with a concrete contract:

1. **Set `reloadableId` on the `WlSessionLock`.** Non-negotiable. This is the difference between
   "lock preserved" and "locked out of the machine".
2. **Persist the lock-requested state in a `PersistentProperties`** (`persistentprops.hpp:41`,
   itself a `Reloadable` designed for exactly this) **[source]**, or otherwise guarantee the new
   generation re-asserts `locked = true` before `onReload`. Without this, row 2 unlocks the
   session on every save.
3. **Never edit the live shell while locked.** The dev-clone workflow in `AGENTS.md` already
   separates dev from live; this makes it a security requirement rather than a convenience.
4. **Treat the whole area as unverified until tested.** See the experiment below.

### Experiment that would settle Q3

On a spare TTY-reachable session (have a TTY login ready — a wrong result locks the machine):

```
qs -p <dev clone>            # with the lock module + reloadableId
qs ipc call lock activate    # lock the session
touch <some qml file>        # force a reload while locked
```

Record: does the screen stay locked, unlock, or go black-with-no-UI? Repeat with
`reloadableId` removed, and with the persisted lock state removed, to confirm rows 2–4.
Check `journalctl --user -u ...` / quickshell stderr for the `qFatal` string
`Tried to show lockscreen surfaces without active lock`.

---

## Q4 — Client death while holding the lock

**Verdict: the HLD is RIGHT, and understates how unpleasant the result is.**

The compositor keeps the session locked; it "must not unlock the session in response" to client
death, and "may choose to continue to display the lock surfaces the client had mapped before it
died or alternatively fall back to a solid color" **[protocol]**. Quickshell's own warning agrees:
"The lock dying will not expose your session, but it will render it inoperable" **[documented]**.

So the session is **secure but unrecoverable from within the session** — no authentication UI
exists any more. Recovery is a TTY (`Ctrl+Alt+F2`), `loginctl unlock-session`, or killing the
compositor. The HLD's failure table says "Hyprland remains locked with fallback color", which is
correct but reads as benign; it should say **"secure, and the session is unrecoverable without a
TTY."**

The HLD's suggestion that "process supervision" helps is **wrong**: restarting quickshell does
not help, because a fresh process cannot adopt the dead process's lock — the new instance's
`lock()` will observe the session already locked and fail. A restarted shell cannot take over the
lock. **[inferred from `manager.cpp:14-18` + protocol]**

---

## Q5 — Output hotplug

**Verdict: the HLD is RIGHT. No `Variants` loop is needed.**

`WlSessionLock::onReload` connects `QGuiApplication::screenAdded`, `screenRemoved` and
`primaryScreenChanged` to `onScreensChanged`, which calls `updateSurfaces(true)` whenever the
manager is locked (`session_lock.cpp:44-48, 153-157`) **[source]**. `updateSurfaces` deletes
surfaces for departed screens and instantiates the `surface` component for any screen that lacks
one (`session_lock.cpp:54-109`) **[source]**. This matches the protocol's requirement that
clients create lock surfaces "for all outputs currently present and any new outputs as they are
advertised" **[protocol]**.

Two details to carry into the spec:

- Screens **not backed by a Wayland screen are skipped** with a debug message
  (`session_lock.cpp:57-66`) **[source]**. On this machine (`eDP-1` + mirrored `HDMI-A-1`) that
  is not expected to matter.
- If the `surface` component does **not** produce a `WlSessionLockSurface`, quickshell logs
  "WlSessionLock.surface does not create a WlSessionLockSurface. Aborting lock." and **unlocks**
  (`session_lock.cpp:82-88`) **[source]**. A QML error in the surface component is therefore an
  unlock path. The surface component must be kept trivially robust — no failure-prone
  construction at its root.

Also: `surface` **cannot be changed while the lock is active** — the setter refuses with a
critical log (`session_lock.cpp:181-185`) **[source]**.

---

## Q6 — `PamContext` lifecycle

**Verdict: the HLD's flow shape is right; its interface is wrong.**

Confirmed sequence **[source, `qml.cpp`]**:

1. **`start()`** → `setActive(true)` → `startConversation()`, which validates
   `configDirectory` is a directory, `config` is a file within it, and resolves the user via
   `getpwuid_r`/`getpwnam_r`, then forks the PAM subprocess. Returns `isActive()`.
2. **`pamMessage`** fires for each PAM prompt, **after** the change signals for `message`,
   `messageIsError`, `responseVisible` and `responseRequired` **[documented + source,
   `qml.cpp:209-236`]** — so those properties are already correct inside the handler.
3. **`respond(x)`** is only accepted when `isActive() && responseRequired`; otherwise it logs
   "PamContext response was ignored as this context does not require one" and drops the response
   (`qml.cpp:121-127`) **[source]**.
4. **`completed(result)`** — always emitted on every terminal outcome (see Q7/Q8).

**Reuse: one context CAN be reused across attempts.** Both `onCompleted` and `onError` call
`abortConversation()` *before* emitting, which deletes the conversation, clears `mTargetActive`,
and resets `message`/`messageIsError`/`responseRequired` (`qml.cpp:96-119, 198-207`) **[source]**.
So by the time your handler runs, `active` is already `false` and a subsequent `start()` works.
Recreating the object per attempt is unnecessary. **Note `config`, `configDirectory` and `user`
may not be set while `active` is true** — they log a critical and are ignored
(`qml.cpp:148-191`) **[source]**.

**`abort()` guarantees**: `abortConversation()` disconnects all signals from the conversation and
`deleteLater()`s it; `~PamConversation` calls `abort()`, which `SIGKILL`s the PAM child and
`waitpid`s it (`conversation.cpp:39, 54-61`) **[source]**. So **`abort()` emits nothing** — no
`completed`, no `error` — and no late signal can arrive from the aborted conversation, because the
connections are severed before deletion. This is a genuine guarantee and it is stronger than the
HLD assumed: the HLD's fingerprint section worries about "stale completion signals from a previous
lock cycle" and prescribes a generation/session identifier. For an **aborted** context that
concern is already handled upstream. A generation counter is still worth keeping for the
two-context fingerprint design, but as belt-and-braces, not as the primary mechanism.

### HLD error: there is no `authenticate(password)`

The HLD's `AuthenticationController` interface declares `function authenticate(password)`. There
is no such call. The real flow is `start()`, then `respond()` from inside `onPamMessage`. The
HLD's own `PamContext` snippet gets this right, so the document **contradicts itself** between its
conceptual interface (line ~119) and its example (line ~130). The conceptual interface is the
wrong one. Corrected below.

### HLD error: `start()` has a silent-failure mode

`start()` returns `bool` and the HLD never checks it. There are two distinct false returns
**[source]**:

- **Silent:** bad `configDirectory`, missing config file, or unknown user → `qCritical` to the log,
  `mTargetActive = false`, return — **no `error`, no `completed`, no signal of any kind.**
- **Signalled synchronously:** subprocess spawn failure → `emit error(InternalError)` →
  `onError` → `completed(PamResult.Error)`, all *before* `start()` returns, which then returns
  false because `abortConversation()` already cleared the conversation
  (`conversation.cpp:41-47`, `qml.cpp:88-94`) **[source]**.

**The first case is a fail-open hazard in any design that assumes "a `completed` always arrives".**
A missing `/etc/pam.d/quickshell-lock` produces *no signal at all*. The controller must treat
`start() === false` as an immediate authentication failure and must not sit waiting for
`completed`.

---

## Q7 — The four `PamResult` values

**Verdict: the HLD handles two of four and its `else` branch is accidentally correct but for the
wrong reason. All four must be handled explicitly.**

Mapping, traced from `pam_authenticate` through the subprocess exit code to the QML signal
**[source, `subprocess.cpp:102-123` → `conversation.cpp:100-107` → `qml.cpp:198-207`]**:

| `PamResult` | Origin | Meaning | Required handling |
|---|---|---|---|
| `Success` | `PAM_SUCCESS` | Authenticated. | **The only value that may unlock.** |
| `Failed` | `PAM_AUTH_ERR` | Wrong credentials. | Stay locked, clear input, allow retry. |
| `MaxTries` | `PAM_MAXTRIES` | The auth method has no attempts left. | Stay locked. **Retrying is pointless** — a new `start()` on the same stack will keep failing. Surface a distinct message and, for fingerprint, stop that provider permanently for this lock cycle. |
| `Error` | **synthesised by `PamContext`**, never by the subprocess | A `PamError` occurred; always preceded by `error(...)`. | Stay locked, report "authentication unavailable". |

`PamResult::Error` is **never** emitted by the conversation layer — it appears in exactly one place
in the codebase, `qml.cpp:206`, immediately after the `error` signal **[source]**.

`MaxTries` is the value the HLD most needs to add. It is semantically *not* a retryable rejection:
`pam_faillock` returning `PAM_MAXTRIES` means the account is temporarily locked out. Presenting it
as "wrong password" trains the user to keep typing into a stack that cannot succeed. It is still
fail-closed, so this is a correctness/UX defect rather than a security hole.

The HLD's `else → internalError("Authentication unavailable")` does fail closed for both `Error`
and `MaxTries`, so the **security** posture survives. But relying on an `else` for a known
enumerated value is exactly the kind of thing that breaks when upstream adds a fifth value.
**Handle all four by name and make the default branch fail closed as a backstop.**

---

## Q8 — `error(PamError)` vs `completed(PamResult)`

**Verdict: `error` is always followed by `completed(PamResult.Error)`. A conversation cannot emit
`error` without `completed` — but a `start()` failure can emit neither.**

`PamContext::onError` does, in order: `abortConversation()`, `emit error(e)`,
`emit completed(PamResult::Error)` (`qml.cpp:203-207`) **[source]**. The header documents it:
"A `completed(PamResult.Error)` will be emitted after this event" (`qml.hpp:104`)
**[documented]**, and the published docs agree **[documented]**.

Note the layering: at the internal `PamConversation` level the two signals *are* mutually
exclusive — `Success`/`Failed`/`MaxTries` emit `completed`, while `StartFailed`/`TryAuthFailed`/
`OtherError` emit `error` (`conversation.cpp:100-107`) **[source]**. `PamContext` is what
synthesises the extra `completed`. Only the `PamContext` behaviour is contractual for QML.

The three `PamError` values **[source, `conversation.cpp:20-27`]**:

| `PamError` | Origin | Meaning |
|---|---|---|
| `StartFailed` | `pam_start_confdir` failed | Config missing/invalid, or PAM stack unusable. |
| `TryAuthFailed` | `pam_authenticate` returned something other than `PAM_SUCCESS`/`PAM_AUTH_ERR`/`PAM_MAXTRIES` | PAM-internal failure (service unavailable, module error). |
| `InternalError` | Quickshell-side | Subprocess spawn failed, or IPC with the PAM child broke mid-conversation. |

**Practical consequence:** handle `completed` as the single terminal transition, and treat `error`
purely as a *diagnostic detail* to enrich the message. Handling both as terminal transitions will
double-fire the state machine.

**And the gap that matters:** the only path with *no* terminal signal is `start()` returning false
for config/user reasons (Q6). `start()`'s return value is part of the terminal contract.

---

## Corrected component contract (supersedes HLD sections 2 and 3)

### SessionLockHost

```qml
WlSessionLock {
    id: sessionLock

    // REQUIRED. Without this the lock is not matched across a hot reload,
    // and a reload while locked aborts the process or strands the session
    // locked with no client. See Q3.
    reloadableId: "sessionLock"

    locked: controller.lockRequested
    surface: lockSurfaceComponent

    // `locked` can go false without QML asking: the compositor may deny the
    // lock (ext_session_lock_v1::finished). Reconcile, never assume.
    onLockedChanged: controller.onCompositorLockStateChanged(locked)
    onSecureChanged: controller.onSecureChanged(secure)
}
```

Rules:

- Exactly **one** `WlSessionLock` in the process. `secure` is process-global.
- **Never** call `sessionLock.unlock()` — private slot, not API (Q1).
- **Never** assign `sessionLock.locked` imperatively anywhere — it destroys the binding (Q1).
- `surface` may not be reassigned while locked.
- The surface component must not fail to construct a `WlSessionLockSurface`: that unlocks (Q5).

### LockController

```
LockController {
    readonly property int state          // see state machine below
    readonly property bool lockRequested // drives WlSessionLock.locked
    readonly property bool secure        // mirrors WlSessionLock.secure
    readonly property bool authenticationRunning
    readonly property string errorMessage

    function requestLock()
    function submitPassword(password)
    function cancelAuthentication()
    function onCompositorLockStateChanged(locked)  // NEW — reconcile denial
    function onSecureChanged(secure)
}
```

`lockRequested` must survive a reload — back it with `PersistentProperties` (Q3).

### AuthenticationController

```
AuthenticationController {
    signal succeeded()
    signal rejected(bool retryable)     // retryable=false for MaxTries
    signal unavailable(string message)  // Error / start() failure

    function beginAuthentication(password)  // NOT authenticate(); see Q6
    function abort()
}
```

```qml
PamContext {
    id: pam
    config: "quickshell-lock"

    onPamMessage: {
        if (responseRequired) pam.respond(auth.pendingPassword)
    }

    onCompleted: result => {
        auth.clearPendingPassword()
        switch (result) {
        case PamResult.Success:  auth.succeeded(); break
        case PamResult.Failed:   auth.rejected(true); break
        case PamResult.MaxTries: auth.rejected(false); break
        case PamResult.Error:    auth.unavailable(auth.lastErrorMessage); break
        default:                 auth.unavailable("Authentication unavailable")
        }
    }

    // Diagnostic only — completed(PamResult.Error) always follows. Do NOT
    // treat this as a terminal transition or the state machine double-fires.
    onError: e => auth.lastErrorMessage = describe(e)
}
```

and `beginAuthentication` must check the return value:

```
if (!pam.start()) {
    // May have emitted nothing at all (bad config path / unknown user).
    auth.clearPendingPassword()
    auth.unavailable("Authentication unavailable")
}
```

### Corrected state machine

The HLD's machine is sound in shape. Three corrections:

1. **`LockRequested` may fail.** Add an edge `LockRequested → LockFailed` when `locked` goes
   false without an authenticated unlock (compositor denial). This state must **not** report
   secure, and must not silently retry.
2. **`MaxTries` is distinguishable from a rejection.** Both return to `Locked`, but `MaxTries`
   must disable retry affordances and show a distinct message.
3. **`Unlocking` is not observable.** The HLD has `UNLOCKING → (compositor unlock completed) →
   UNLOCKED`. There is no confirmation event for unlock: `unlock_and_destroy` is fire-and-forget
   and the lock object is deleted immediately (`session_lock/session_lock.cpp:39-46`) **[source]**.
   `Unlocking` should therefore be a transient bookkeeping state that transitions on the
   `lockStateChanged` that follows, not a state awaiting compositor acknowledgement.

```
Unlocked ──requestLock()──► LockRequested
                              │  secure == true          │ locked→false (denied)
                              ▼                          ▼
                            Locked                    LockFailed (fail closed)
                              │ submitPassword()
                              ▼
                         Authenticating
                              ├── Failed              ──► Locked (retry allowed)
                              ├── MaxTries            ──► Locked (retry disabled)
                              ├── Error / !start()    ──► Locked (unavailable)
                              └── Success             ──► Unlocking ──► Unlocked
```

Invariants (HLD's list, corrected and extended):

- `LockRequested` is never treated as securely locked. **(HLD: correct)**
- Only `PamResult.Success` permits `Unlocking`. **(HLD: correct)**
- Every non-`Success` outcome, **and a false return from `start()`**, fails closed. **(extended)**
- `locked` going false is reconciled, never ignored. **(new)**
- Crashing must not reveal the session — and will leave it unrecoverable without a TTY. **(HLD:
  correct, consequence understated)**
- Hot reload while locked is safe **only** with `reloadableId` set *and* lock state persisted.
  **(new — HLD was wrong)**
- Adding a monitor while locked produces a surface automatically. **(HLD: correct)**
- Unlock is a single global operation. **(HLD: correct)**

---

## Every place the HLD is wrong

| # | HLD location | Error | Correction |
|---|---|---|---|
| 1 | §2 `AuthenticationController` interface, `function authenticate(password)` | No such API exists; contradicts the HLD's own PamContext snippet. | `start()` then `respond()` inside `onPamMessage`. |
| 2 | §2 PamContext snippet, `onCompleted` | Handles only `Success`/`Failed`; `MaxTries` and `Error` fall into a generic `else`. | Handle all four by name; `MaxTries` is non-retryable, not a rejection. |
| 3 | §2/§8 | `start()`'s `bool` return is never checked; a missing/invalid PAM config emits **no signal at all**. | Treat `start() === false` as immediate failure. |
| 4 | §3 state machine | No state for compositor lock **denial** (`ext_session_lock_v1::finished`); `locked` can go false unbidden. | Add `LockFailed`; reconcile `onLockedChanged`. |
| 5 | §3 state machine | `UNLOCKING → compositor unlock completed` implies an acknowledgement that does not exist. | Transient state; no confirmation event. |
| 6 | §11 checklist | *"QML reload/restart is disabled or carefully controlled while locked"* — unimplementable (QML cannot refuse a reload) and wrong about intent: Quickshell **tries to preserve** the lock. | Set `reloadableId`; persist lock state via `PersistentProperties`; never edit the live shell while locked. |
| 7 | §8 failure table, "Quickshell crash after secure lock → Hyprland remains locked with fallback color" | Reads as benign. | Secure but **unrecoverable without a TTY**. |
| 8 | §8 narrative, "process supervision ... important" | A restarted quickshell **cannot** adopt the orphaned lock. | Supervision does not help; prevention does. |
| 9 | §6 fingerprint, "use a generation/session identifier to reject late results" | Over-cautious for the abort case — `abort()` severs connections before deletion, so no late signals arrive. | Keep as defence-in-depth, not the primary mechanism. |
| 10 | §5 PAM, "Test expired passwords, locked accounts" | `PamContext` runs **only** the `auth` type — `pam_acct_mgmt` is never called **[documented]**, so account expiry/lockout is not evaluated at all. | Do not expect `account` rules to be enforced. Expired-password handling is out of reach of this API. |
| 11 | §2 (implicit) | Does not warn that the upstream doc example `onClicked: lock.locked = false` destroys the `locked` binding. | Ban imperative writes to `locked`. |

**Not in the HLD, worth adding to the spec:**

- `configDirectory` resolves **relative to the QML file** when not absolute **[documented +
  source]**. This makes it trivially possible to ship a PAM config inside this repo — which
  would be a user-writable authentication policy and a complete auth bypass. The HLD's
  "root-owned `/etc/pam.d/quickshell-lock`" requirement is right; this is the concrete footgun
  it is guarding against. Leave `configDirectory` at its `/etc/pam.d` default.
- The docs' claim that a second concurrent lock "will do nothing" is **false** in-process: it
  `qFatal`s (Q3, row 3).

---

## What I could not establish

- **The observed behaviour of a real hot reload while locked.** Rows 1–4 of the Q3 table are
  derived from reading `onReload`/`realizeLockTarget`/`updateSurfaces` and the reload ordering in
  `generation.cpp`. They are consistent and I am confident in the mechanism, but I did not run
  them. The experiment is in Q3 — run it from a TTY-reachable session before trusting hot reload
  while locked.
- **Whether a matched reload trips a `duplicate_output` protocol error.** The `updateSurfaces(false)`
  / `updateSurfaces(true, old)` ordering appears to make surface-window adoption unreachable,
  which would mean new surfaces are created for outputs that already have one. Whether the old
  surfaces' wayland objects are destroyed early enough to avoid the error depends on
  `deleteLater()` timing I did not trace to completion. The same experiment settles it: watch for
  a wayland protocol error / abrupt client disconnect on the first reload while locked.
- **No independent practitioner corroboration** of the reload-while-locked behaviour was found;
  web results only restated the docs. The conclusions above rest on the primary source, which for
  mechanism questions is the stronger evidence, but a second pair of eyes on the Q3 table before
  it becomes a build spec would be worthwhile.
