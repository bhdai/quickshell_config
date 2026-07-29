pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import "LockLogic.js" as LockLogic

/**
 * Owns everything security-relevant about the lock screen: the state machine, the
 * PAM conversation, the persisted lock state and the single-winner latch.
 *
 * The lock surface reads this singleton and calls `submit()`. It never sees the
 * WlSessionLock, so there is no object on which the view layer could set `locked`;
 * the only clear is `priv.grant()`, which is reachable only from a PamResult.Success.
 *
 * Two behaviours that are correct but surprising, recorded rather than fixed:
 *
 * - An expired password still unlocks. PamContext calls pam_authenticate and nothing
 *   else, so the account stack never runs and expiry is never evaluated. That is right
 *   for a locker: it guards a session the user already authenticated into rather than
 *   granting a new one, and hyprlock and swaylock behave the same way.
 * - Clearing `password` does not zero memory. QML strings are immutable and garbage
 *   collected, so assigning "" drops the reference and leaves the old bytes for the
 *   collector. No option available in QML does better; the password is dropped as
 *   early as possible instead.
 */
Singleton {
    id: root

    // Drives WlSessionLock.locked, and is the only thing that does. Readonly here and
    // backed by an object the rest of the shell cannot name, so nothing outside this
    // file can clear the lock.
    readonly property bool lockRequested: persist.locked

    // Compositor-confirmed: every output is covered and no unlocked content can be
    // visible. `lockRequested` is only the request.
    readonly property bool secure: priv.secure

    readonly property string lockState: priv.lockState
    readonly property string message: priv.message

    // How the message should read, as a LockLogic.MessageRole. It is the result code the
    // surface treats the outcome by, never the message text: lockout copy is translated and
    // reworded by whatever module sent it, so matching on it would break outside an English
    // locale, while the code is the same value on every machine.
    readonly property string messageRole: priv.messageRole

    // The password lives here rather than on a surface so that every output's field
    // edits the same string and mirrored monitors stay in sync while typing.
    property string password: ""

    // How many characters went out with the last response. The password is dropped at
    // submit rather than kept until the result arrives, so this is what lets the field
    // keep showing its dots while authentication is in flight. Length only, never content.
    property int submittedLength: 0

    // Whether the surfaces are showing the authentication area or resting. View state
    // rather than lock state, held here for the same reason the password is: the mirrored
    // output reveals and dismisses with the one holding keyboard focus. Nothing reads it
    // on the way to a grant.
    property bool authRevealed: false

    readonly property bool acceptingInput: priv.lockState === LockLogic.State.Locked && priv.promptReady && pam.active
    readonly property bool authenticating: priv.lockState === LockLogic.State.Authenticating

    // Prompt text and echo behaviour come from the conversation, so changing the PAM
    // policy does not require changing the UI.
    readonly property string prompt: priv.promptReady ? pam.message : ""
    readonly property bool echoResponse: pam.responseVisible

    function requestLock(): bool {
        priv.dispatch(LockLogic.Event.LockRequested);
        return persist.locked;
    }

    function submit(): void {
        if (!root.acceptingInput)
            return;
        priv.dispatch(LockLogic.Event.Submit);
    }

    // Reported by the lock host. `secure` is an input as well as an output: it re-rises
    // on every preserved hot reload.
    function reportSecure(secure: bool): void {
        priv.secure = secure;
        priv.dispatch(secure ? LockLogic.Event.Secure : LockLogic.Event.Insecure);
    }

    // `locked` can go false without QML asking — the compositor sends `finished` when it
    // denies the lock or hands it to someone else. Nothing authenticated, so reconcile
    // rather than treating it as an unlock.
    function reportLocked(locked: bool): void {
        if (!locked && persist.locked)
            priv.dispatch(LockLogic.Event.Denied);
    }

    // Walking away must not leave half a password sitting on screen where the next person
    // to touch the machine can count the characters. Silent by design: it writes no message,
    // so a lockout notice underneath survives the clear.
    onPasswordChanged: {
        if (root.password.length > 0 && priv.lockState === LockLogic.State.Locked)
            idleClear.restart();
        else
            idleClear.stop();
    }

    // Reload matches this object by its index among the singleton's children. Adding a
    // child above it while the screen is locked drops the persisted state, and the lock
    // goes with it.
    PersistentProperties {
        id: persist

        // Without this surviving a reload, saving any loaded QML file while locked
        // opens the screen: the new generation constructs the property as false and the
        // binding writes it straight through to the compositor. Observed, twice, in #57.
        property bool locked: false
    }

    // Declared below PersistentProperties rather than above it, because that object is
    // matched across a reload by its index among these children.
    Timer {
        id: idleClear

        interval: 10000
        onTriggered: root.password = ""
    }

    // The machine and the grant live in an unnamed child so that nothing outside this
    // file can name them. `Lock.submit()` is the whole of the view layer's reach.
    QtObject {
        id: priv

        property string lockState: LockLogic.State.Unlocked
        property bool secure: false
        property string message: ""
        property string messageRole: LockLogic.MessageRole.None

        // Set once a grant has fired, so a second success in the same cycle is a no-op.
        // Cleared when a new lock is raised.
        property bool granted: false

        // Whether a response actually went out since the context was armed. A locked-out
        // account fails the pam_authenticate preauth before anything is typed; re-arming
        // on that failure spins and hammers the failure counter.
        property bool respondedThisCycle: false

        // One response per prompt, never replayed across prompts — that is what stops a
        // multi-prompt stack silently degrading into a single factor.
        property bool promptReady: false

        property string lastErrorMessage: ""

        // The last non-prompt message PAM sent this cycle. Kept because it is the only
        // evidence account lockout exists: the stack refuses with a plain failure and
        // explains itself here and nowhere else.
        property string conversationMessage: ""

        function dispatch(event: string): void {
            const transition = LockLogic.nextState(priv.lockState, event);
            priv.lockState = transition.next;
            priv.applyEffects(transition.effects);
        }

        function applyEffects(effects: var): void {
            for (const effect of effects) {
                switch (effect) {
                case LockLogic.Effect.RaiseLock:
                    priv.granted = false;
                    root.authRevealed = false;
                    persist.locked = true;
                    break;
                case LockLogic.Effect.ReleaseLock:
                    persist.locked = false;
                    break;
                case LockLogic.Effect.Arm:
                    priv.arm();
                    break;
                case LockLogic.Effect.Disarm:
                    priv.disarm();
                    break;
                case LockLogic.Effect.SendResponse:
                    priv.sendResponse();
                    break;
                case LockLogic.Effect.Grant:
                    priv.grant();
                    break;
                }
            }
        }

        function arm(): void {
            // Idempotent, because `secure` rises again on every preserved hot reload.
            if (pam.active)
                return;

            priv.respondedThisCycle = false;
            priv.promptReady = false;
            priv.lastErrorMessage = "";
            priv.conversationMessage = "";
            pam.start();

            // A bad policy path or an unresolvable user logs and returns without emitting
            // anything at all, so the active flag is the only evidence a conversation
            // exists. Waiting for a completion that will never arrive would hang the lock
            // on a mute failure.
            if (!pam.active) {
                const action = LockLogic.errorAction(LockLogic.PamError.StartFailed);
                priv.message = priv.lastErrorMessage || action.message;
                priv.messageRole = action.messageRole;
            }
        }

        function disarm(): void {
            if (pam.active)
                pam.abort();
        }

        function sendResponse(): void {
            pam.respond(root.password);
            priv.respondedThisCycle = true;
            priv.promptReady = false;
            root.submittedLength = root.password.length;
            root.password = "";
        }

        function grant(): void {
            if (priv.granted)
                return;

            priv.granted = true;
            priv.disarm();
            root.password = "";
            root.submittedLength = 0;
            priv.message = "";
            priv.messageRole = LockLogic.MessageRole.None;
            persist.locked = false;

            // A fingerprint touch is USB traffic rather than compositor input, so nothing
            // wakes the display on that path and the user would be handed an unlocked
            // desktop on a black screen. Harmless after a password unlock, where typing
            // already woke it.
            Hyprland.dispatch('hl.dsp.dpms({ action = "enable" })');
        }

        function resultName(result: int): string {
            switch (result) {
            case PamResult.Success:
                return LockLogic.Result.Success;
            case PamResult.Failed:
                return LockLogic.Result.Failed;
            case PamResult.MaxTries:
                return LockLogic.Result.MaxTries;
            case PamResult.Error:
                return LockLogic.Result.Error;
            default:
                return "unknown";
            }
        }

        function errorName(error: int): string {
            switch (error) {
            case PamError.StartFailed:
                return LockLogic.PamError.StartFailed;
            case PamError.TryAuthFailed:
                return LockLogic.PamError.TryAuthFailed;
            case PamError.InternalError:
                return LockLogic.PamError.InternalError;
            default:
                return "unknown";
            }
        }
    }

    PamContext {
        id: pam

        // configDirectory is left at its /etc/pam.d default. A relative one resolves
        // against this QML file, which would make the authentication policy user-writable
        // — a complete bypass. `user` is left unset so it resolves the real uid of this
        // process, which is the session owner by construction.
        config: "quickshell-lock"

        onPamMessage: {
            if (pam.responseRequired) {
                priv.promptReady = true;
                return;
            }

            // Non-prompt messages carry what the result code cannot, notably the account
            // lockout text and how long it lasts.
            priv.conversationMessage = pam.message;
            priv.message = pam.message;
            priv.messageRole = pam.messageIsError ? LockLogic.MessageRole.Error : LockLogic.MessageRole.None;
        }

        onCompleted: result => {
            const action = LockLogic.passwordAction(priv.resultName(result), priv.respondedThisCycle);
            priv.dispatch(action.event);

            const display = LockLogic.displayMessage(action, priv.conversationMessage, priv.lastErrorMessage);
            priv.message = display.message;
            priv.messageRole = display.messageRole;
            priv.applyEffects(action.effects);
        }

        // Diagnostic only. A completed(PamResult.Error) always follows, and that
        // completion is the single terminal transition — treating both as terminal
        // double-fires the machine.
        onError: error => {
            priv.lastErrorMessage = LockLogic.errorAction(priv.errorName(error)).message;
        }
    }

    IpcHandler {
        target: "lock"

        // Value-matched by hypridle's lock_cmd: `qs ipc call` exits 0 even when the
        // target or function is missing, so the returned value is the only thing that
        // distinguishes a raised lock from a shell that failed to load this module.
        function lock(): bool {
            return root.requestLock();
        }

        // There is deliberately no unlock: it would reintroduce an unauthenticated,
        // same-uid clear of an active lock screen.
        function isLocked(): bool {
            return root.secure;
        }
    }
}
