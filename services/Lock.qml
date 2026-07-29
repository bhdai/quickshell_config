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
 * Two contexts run here, against two policies, at the same time. That is a hard
 * constraint rather than a preference: pam_fprintd blocks in its D-Bus verify loop for up
 * to ninety seconds without ever calling the conversation function, so under one combined
 * policy the password could not be submitted while a scan was still running. First success
 * wins, the latch makes it the only one, and the two never touch otherwise — a rejected
 * finger does not abort the password conversation, clear its field or steal its focus.
 *
 * Three behaviours that are correct but surprising, recorded rather than fixed:
 *
 * - An expired password still unlocks. PamContext calls pam_authenticate and nothing
 *   else, so the account stack never runs and expiry is never evaluated. That is right
 *   for a locker: it guards a session the user already authenticated into rather than
 *   granting a new one, and hyprlock and swaylock behave the same way.
 * - Clearing `password` does not zero memory. QML strings are immutable and garbage
 *   collected, so assigning "" drops the reference and leaves the old bytes for the
 *   collector. No option available in QML does better; the password is dropped as
 *   early as possible instead.
 * - The fingerprint context holds the reader claimed for the whole lock, re-claiming it
 *   every scan cycle. No other fingerprint consumer can use the device while the screen
 *   is locked. That is the price of "touch the reader to wake and unlock in one motion",
 *   which is the best property this design has.
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

    // What the fingerprint affordance should show, as a LockLogic.Fingerprint. Absent
    // until the reader has proven itself by talking, so a machine without one — or
    // without an enrolment, or with fprintd down — offers nothing rather than offering
    // something that cannot happen.
    readonly property string fingerprintState: LockLogic.fingerprintState(priv.fingerprintAvailable, priv.fingerprintStopped, priv.fingerprintFeedback)

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

    onPasswordChanged: {
        // Typing is the start of a new attempt, and the last attempt's verdict is not about
        // it — leaving it up would still be saying "password incorrect" about a password
        // nobody has submitted yet. The account-lockout notice cannot be lost this way: that
        // failure leaves the context un-armed, so there is nothing to type into.
        if (root.password.length > 0) {
            priv.message = "";
            priv.messageRole = LockLogic.MessageRole.None;
        }

        // Walking away must not leave half a password sitting on screen where the next person
        // to touch the machine can count the characters. Silent by design: it writes no
        // message of its own.
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

    // Every arm of the reader goes through here rather than starting it inline. Restarting
    // a context from inside its own completion handler is reentrancy resting on emission
    // order, and the delay bounds the blast radius if the stop-or-retry classification is
    // ever wrong: an unbounded fork loop becomes a few attempts a second, which is a bug
    // you notice in the journal rather than a wedged laptop behind a locked screen. It is
    // invisible either way — lifting and replacing a finger takes far longer.
    Timer {
        id: fingerprintArm

        // The gap for an ordinary re-arm. `interval` itself is written by both arm paths
        // — the retry one substitutes a backoff — so it is held here rather than being
        // the property's own default, which a single backoff would overwrite for good.
        readonly property int promptInterval: 250

        interval: promptInterval
        onTriggered: priv.armFingerprint()
    }

    // A rejected scan re-arms immediately, and the module greets the new cycle within
    // milliseconds, so without this the feedback would be replaced by "touch the reader"
    // before it could be read.
    Timer {
        id: fingerprintFeedbackHold

        interval: 2000
        onTriggered: priv.fingerprintFeedback = LockLogic.Fingerprint.Armed
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

        // Whether the reader has ever spoken this lock. The module sends its prompt only
        // after enumerating devices, finding an enrolled finger and claiming the reader,
        // so one message is the whole of the availability check — no D-Bus probe, no
        // subprocess on the lock path, and no staleness window. Sticky, so the affordance
        // does not blink out between scan cycles.
        property bool fingerprintAvailable: false

        // Whether a message arrived since this scan cycle was armed. Resets on every arm,
        // and is the only thing that separates a thirty-second timeout from a reader that
        // is not there.
        property bool fingerprintSawMessage: false

        // Set once the retry budget below is spent, and so for the rest of this lock
        // session. Nothing but a new lock clears it: by that point the evidence says the
        // device is gone for good, and re-arming on that is the fork loop.
        property bool fingerprintStopped: false

        // Re-arms spent against a reader that refused to start, this lock session. Reset
        // by any message, because a module that spoke has claimed a working reader — so a
        // wedge later in the same lock gets the whole budget again rather than the
        // remainder of one spent on an unrelated stumble hours earlier.
        property int fingerprintRetries: 0

        property string fingerprintFeedback: LockLogic.Fingerprint.Armed

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
                    priv.fingerprintAvailable = false;
                    priv.fingerprintStopped = false;
                    priv.fingerprintRetries = 0;
                    priv.fingerprintFeedback = LockLogic.Fingerprint.Armed;
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
                case LockLogic.Effect.ArmFingerprint:
                    priv.requestFingerprintArm();
                    break;
                case LockLogic.Effect.DisarmFingerprint:
                    priv.disarmFingerprint();
                    break;
                case LockLogic.Effect.StopFingerprint:
                    priv.stopOrRetryFingerprint();
                    break;
                case LockLogic.Effect.RevealAuth:
                    root.authRevealed = true;
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

        function requestFingerprintArm(): void {
            if (priv.fingerprintStopped)
                return;

            // Explicit, because the retry path writes this same property: without it a
            // scan following a backoff would inherit that backoff's interval.
            fingerprintArm.interval = fingerprintArm.promptInterval;
            fingerprintArm.restart();
        }

        function armFingerprint(): void {
            // Idempotent for the same reason arm() is: `secure` rises again on every
            // preserved hot reload.
            if (priv.fingerprintStopped || fingerprint.active)
                return;

            priv.fingerprintSawMessage = false;
            fingerprint.start();

            // A missing quickshell-fprint policy returns false having emitted nothing at
            // all, so no completion will ever arrive and this is the only place that
            // refusal is observable. It goes through the same budget as every other stop:
            // the refusal is identical whether the policy is missing or the reader is
            // mid-reset, and only spending the retries tells the two apart. The password
            // is untouched either way — the factors are independent, and a missing file
            // for one is the install step not having been run rather than an attack.
            if (!fingerprint.active)
                priv.stopOrRetryFingerprint();
        }

        // A stop is a verdict on this attempt, not on the reader. Hardware that wedges
        // comes back on its own — measured here, a reader that fell off the USB bus was
        // re-enumerated about a second later — so the budget is spent before the chip is
        // taken away for the rest of the lock. Exhausting it lands exactly where the
        // unconditional stop used to.
        function stopOrRetryFingerprint(): void {
            const delay = LockLogic.fingerprintRetryDelay(priv.fingerprintRetries);
            if (delay < 0) {
                priv.fingerprintStopped = true;
                return;
            }

            priv.fingerprintRetries += 1;
            fingerprintArm.interval = delay;
            fingerprintArm.restart();
        }

        function disarmFingerprint(): void {
            fingerprintArm.stop();
            fingerprintFeedbackHold.stop();

            // abort() severs the conversation's signals before deleting it and SIGKILLs
            // the PAM child, so nothing arrives afterwards and no generation counter is
            // needed to reject it.
            if (fingerprint.active)
                fingerprint.abort();
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
            priv.disarmFingerprint();

            // Before the lock is released, so a fingerprint win never hands back a desktop
            // with a half-typed password still sitting in the field of a surface that is
            // about to be destroyed.
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

    PamContext {
        id: fingerprint

        // A separate root-owned policy, carrying pam_fprintd with max-tries=1 and
        // deliberately no failure counter: a password lockout must not be able to disable
        // the reader. The retry loop lives in QML instead, which is what stops the module
        // blocking for ninety seconds in one call.
        config: "quickshell-fprint"

        onPamMessage: {
            // Never responded to, and there is nothing here to respond to: this stack has
            // no response-requiring prompt. The generic "one response per prompt" rule the
            // password context follows exists to stop a multi-prompt stack degrading into
            // a single factor, and with no prompt there is no such hazard to guard.
            priv.fingerprintSawMessage = true;
            priv.fingerprintAvailable = true;

            // The module speaks only once it has claimed a working reader, so this is
            // proof the hardware recovered and the spent retries were the wedge rather
            // than a policy that will refuse forever.
            priv.fingerprintRetries = 0;
        }

        onCompleted: result => {
            const action = LockLogic.fingerprintAction(priv.resultName(result), priv.fingerprintSawMessage);

            priv.fingerprintFeedback = action.feedback;
            if (action.feedback === LockLogic.Fingerprint.Rejected)
                fingerprintFeedbackHold.restart();

            // Only a win is dispatched. A failed scan leaves the password machine exactly
            // where it was — mid-authentication if a response is in flight, resting
            // otherwise — and writes nothing into its message.
            if (action.event)
                priv.dispatch(action.event);

            priv.applyEffects(action.effects);
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
