import Quickshell
import Quickshell.Wayland
import qs.services

/**
 * Hosts the shell's one and only WlSessionLock. `secure` is derived from a
 * process-global static, so a second one anywhere would make both report secure
 * whenever either is.
 *
 * No reloadableId: it looks like the mitigation for a reload while locked and is
 * not one. Matching is decided by index position among the enclosing propagator's
 * children and the id is never consulted — four paired runs in #57 confirmed it,
 * including one where the id changed mid-lock and the instance still matched.
 * What actually keeps the lock across a reload is the persisted state in `Lock`.
 */
Scope {
    WlSessionLock {
        id: sessionLock

        // The only correct mechanic. `unlock()` is a private slot that leaks into the
        // metaobject and desyncs this binding, and an imperative write to `locked`
        // destroys the binding permanently, after which nothing locks again.
        locked: Lock.lockRequested

        onLockedChanged: Lock.reportLocked(sessionLock.locked)
        onSecureChanged: Lock.reportSecure(sessionLock.secure)

        // If this component fails to produce a WlSessionLockSurface, Quickshell aborts
        // the lock — a QML error in here is an unlock path.
        surface: LockSurface {}
    }
}
