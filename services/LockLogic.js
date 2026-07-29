.pragma library

// Every security-relevant decision the lock screen makes. `Lock.qml` is a dumb
// applier over these descriptors: it translates PAM signals into the constants
// below, hands them here, and performs whatever effects come back. The split
// exists because there is no display in CI and the one property that must hold
// -- no outcome other than a PAM success ever clears the lock -- is exactly the
// property a spurious unlock would hide from anyone reading the screen.

const State = {
    Unlocked: "unlocked",
    Locking: "locking",
    Locked: "locked",
    Authenticating: "authenticating",
};

const Event = {
    LockRequested: "lockRequested",
    Secure: "secure",
    Insecure: "insecure",
    Submit: "submit",
    Success: "success",
    FingerprintSuccess: "fingerprintSuccess",
    Failure: "failure",
    Denied: "denied",
};

const Effect = {
    RaiseLock: "raiseLock",
    Arm: "arm",
    Disarm: "disarm",
    SendResponse: "sendResponse",
    Grant: "grant",
    ReleaseLock: "releaseLock",
    ArmFingerprint: "armFingerprint",
    DisarmFingerprint: "disarmFingerprint",
    StopFingerprint: "stopFingerprint",
    RevealAuth: "revealAuth",
};

// PamResult.Enum and PamError.Enum, as names rather than the numeric values, so
// a reordering of the upstream enum cannot silently repoint a branch.
const Result = {
    Success: "success",
    Failed: "failed",
    MaxTries: "maxTries",
    Error: "error",
};

const PamError = {
    StartFailed: "startFailed",
    TryAuthFailed: "tryAuthFailed",
    InternalError: "internalError",
};

const MessageRole = {
    None: "none",
    Error: "error",
    Warning: "warning",
    Unavailable: "unavailable",
};

// What the fingerprint affordance is showing. Not a lock state: the reader is armed for
// the whole of `secure` and runs alongside whatever the password machine is doing, so it
// has no say in the enum above and cannot hold the machine anywhere.
//
// There is deliberately no state for a win. The grant runs in the same handler that would
// set it and releases the lock synchronously, so the surface is gone before a frame could
// be drawn — a "fingerprint recognized" treatment would be a branch nothing can ever see.
const Fingerprint = {
    Absent: "absent",
    Armed: "armed",
    Rejected: "rejected",
};

/**
 * The state machine. Returns { next, effects } — the caller applies the effects
 * in order and stores `next`.
 *
 * Failure is an event, not a state: the visual pacing of a rejection belongs to
 * the surface, not here.
 */
function nextState(state, event) {
    switch (event) {
    case Event.LockRequested:
        return state === State.Unlocked ? transition(State.Locking, [Effect.RaiseLock]) : transition(state);

    case Event.Secure:
        // A preserved hot reload re-raises secure, so this is reachable from any
        // state and must always land on the same one.
        //
        // Both factors arm here rather than on `locked` or on surface construction.
        // Before the compositor confirms it has stopped routing input to ordinary
        // clients, a touch on the reader would authenticate against a screen that is
        // not yet covering the desktop.
        return transition(State.Locked, [Effect.Arm, Effect.ArmFingerprint]);

    case Event.Insecure:
        return state === State.Unlocked ? transition(state, [Effect.Disarm, Effect.DisarmFingerprint]) : transition(State.Locking, [Effect.Disarm, Effect.DisarmFingerprint]);

    case Event.Submit:
        return state === State.Locked ? transition(State.Authenticating, [Effect.SendResponse]) : transition(state);

    case Event.Success:
        // The only edge that produces a grant. A success arriving in any other
        // state is a late or duplicate signal and must not unlock.
        return state === State.Authenticating ? transition(State.Unlocked, [Effect.Grant]) : transition(state);

    case Event.FingerprintSuccess:
        // The reader is not part of the password machine's flow, so a win can land in
        // either state a scan can complete in. It cannot land in Locking — the reader is
        // only armed once secure, and losing secure aborts the context — and a success
        // there would be a grant against a screen the compositor is not confirming, so
        // the pair is named rather than everything-but-Unlocked.
        return state === State.Locked || state === State.Authenticating ? transition(State.Unlocked, [Effect.Grant]) : transition(state);

    case Event.Failure:
        return state === State.Unlocked ? transition(state) : transition(State.Locked);

    case Event.Denied:
        // The compositor refused or dropped the lock. Nothing authenticated, so
        // the persisted request is released rather than granted.
        return transition(State.Unlocked, [Effect.Disarm, Effect.DisarmFingerprint, Effect.ReleaseLock]);

    default:
        return transition(state);
    }
}

/**
 * What to do with a completed password conversation.
 *
 * `respondedThisCycle` is whether a response actually went out since the context
 * was armed, and it is the whole of the failure-counter hazard: starting the
 * context runs pam_authenticate, so a locked-out account completes as a failure
 * before the user has typed anything. Re-arming on that spins forever, hammering
 * the counter. With no response sent, the machine sits still instead.
 *
 * Returns { event, effects, message, messageRole }: feed `event` to nextState,
 * then apply `effects`.
 */
function passwordAction(result, respondedThisCycle) {
    const rearm = respondedThisCycle ? [Effect.Arm] : [];

    switch (result) {
    case Result.Success:
        return { event: Event.Success, effects: [], message: "", messageRole: MessageRole.None };

    case Result.Failed:
        return {
            event: Event.Failure,
            effects: rearm,
            message: "Password incorrect. Try again.",
            messageRole: MessageRole.Error,
        };

    case Result.MaxTries:
        return {
            event: Event.Failure,
            effects: rearm,
            message: "Too many failed attempts. Wait a moment, then try again.",
            messageRole: MessageRole.Warning,
        };

    case Result.Error:
        return {
            event: Event.Failure,
            effects: rearm,
            message: "Password authentication is unavailable. Try again.",
            messageRole: MessageRole.Unavailable,
        };

    default:
        // A value this build does not know about. Fail closed and do not retry.
        return {
            event: Event.Failure,
            effects: [],
            message: "Password authentication is unavailable. Try again.",
            messageRole: MessageRole.Unavailable,
        };
    }
}

/**
 * What to display for a completed conversation, given the descriptor from
 * `passwordAction` and whatever text arrived on the way: `conversationMessage` is
 * the last non-prompt message PAM sent this cycle, `errorMessage` the description
 * of a PamError signal.
 *
 * Account lockout has no result code of its own — pam_faillock refuses with a
 * plain failure and says why only in the message text — so anything PAM actually
 * said outranks the generic copy for the result. Without that, "Password
 * incorrect. Try again." paints over the one sentence explaining that trying
 * again is not what is wrong, and the user retypes and never learns why.
 *
 * The role stays the result's own: the message says what happened, the result
 * says how bad it is, and only the result is trustworthy enough to colour by.
 */
function displayMessage(action, conversationMessage, errorMessage) {
    return {
        message: conversationMessage || errorMessage || action.message,
        messageRole: action.messageRole,
    };
}

/**
 * What to do with a completed fingerprint conversation. Runs against its own policy in
 * its own context, concurrently with the password one, because `pam_fprintd` blocks in
 * its D-Bus verify loop without ever calling the conversation function — under a single
 * combined policy the password field could not be submitted while a scan was pending.
 *
 * `sawMessageThisCycle` is whether the module said anything since this context was armed,
 * and it carries the whole of the fork-loop hazard. `Error` conflates "you took thirty
 * seconds" with "there is no reader", and with no reader the module returns instantly, so
 * re-arming blindly on it spins behind a locked screen. The module sends its prompt only
 * after enumerating devices, finding an enrolled finger and claiming the reader, so a
 * message having arrived is proof the device was there and leaves the timeout as the only
 * thing the error can have been. Arrival rather than content, because the timeout string
 * is syslog-only and never reaches the message property.
 *
 * Returns { event, effects, feedback }: `event` is null for everything but a win, since a
 * failed scan must not move the password machine.
 */
function fingerprintAction(result, sawMessageThisCycle) {
    switch (result) {
    case Result.Success:
        // The feedback is the resting one because the win has none to give: the grant
        // tears the affordance down along with the lock before anything could render.
        return { event: Event.FingerprintSuccess, effects: [], feedback: Fingerprint.Armed };

    case Result.MaxTries:
        // Under max-tries=1 this is "that finger did not match" and nothing else. It
        // re-arms unconditionally: the fingerprint policy was deliberately kept free of
        // pam_faillock so that a password lockout cannot disable the reader, and a cap
        // counted here would smuggle that lockout back in through the side door.
        //
        // It reveals because the chip lives inside the revealed tier: from the resting
        // view the shake and the copy would render at zero opacity, and a refused finger
        // would be indistinguishable from a dead sensor. This is the only outcome that
        // reveals — it is the only one where the user was told no rather than the reader
        // failing, and the reveal lands them on the factor that still works.
        return { event: null, effects: [Effect.ArmFingerprint, Effect.RevealAuth], feedback: Fingerprint.Rejected };

    case Result.Error:
        return sawMessageThisCycle ? { event: null, effects: [Effect.ArmFingerprint], feedback: Fingerprint.Armed } : { event: null, effects: [Effect.StopFingerprint], feedback: Fingerprint.Absent };

    default:
        // Including Failed, which this stack has no way to produce: one module, and a
        // finger it refuses comes back as MaxTries. Stop quietly rather than retry
        // something whose meaning is not known on this build.
        return { event: null, effects: [Effect.StopFingerprint], feedback: Fingerprint.Absent };
    }
}

// Backoff before re-arming a reader that refused to start, in milliseconds per attempt.
// Finite because an unslowed retry is the fork loop again: a missing quickshell-fprint
// policy refuses instantly and forever, and only exhausting a budget distinguishes that
// from hardware that is coming back.
const FingerprintRetryDelays = [2000, 5000, 10000];

/**
 * How long to wait before the nth re-arm of a stopped reader, or a negative number once
 * the budget is spent and the stop should become permanent for this lock session.
 *
 * The budget exists because a stop is not proof the reader is gone for good. Measured on
 * this machine: a `ReleaseDevice` that timed out wedged the Prometheus, which dropped off
 * the USB bus and re-enumerated under a new device number about a second later. fprintd
 * reported no device for that window, so the first refusal arrived while the hardware was
 * merely mid-reset — and a stop that was permanent on it left the chip absent for the rest
 * of a lock the reader was healthy for.
 *
 * @param attempt how many re-arms have already been spent this lock session, from 0
 */
function fingerprintRetryDelay(attempt) {
    return attempt < FingerprintRetryDelays.length ? FingerprintRetryDelays[attempt] : -1;
}

/**
 * What the affordance shows, given whether a message has ever proven the reader exists,
 * whether the retry loop has stopped for this lock session, and the feedback from the
 * last completed scan.
 *
 * Availability is sticky once proven so that the affordance does not blink out between
 * scan cycles, and only a stop takes it away.
 */
function fingerprintState(available, stopped, feedback) {
    if (stopped || !available)
        return Fingerprint.Absent;

    return feedback === Fingerprint.Rejected ? Fingerprint.Rejected : Fingerprint.Armed;
}

/**
 * Describes a PamError for display. Diagnostic only — PamContext always emits a
 * completion carrying PamResult.Error after this signal, and that completion is
 * the single terminal transition. Returning an event here would double-fire the
 * machine, so `event` is always null.
 */
function errorAction(pamError) {
    return {
        event: null,
        effects: [],
        message: errorMessage(pamError),
        messageRole: MessageRole.Unavailable,
    };
}

function errorMessage(pamError) {
    switch (pamError) {
    case PamError.StartFailed:
        return "Authentication is unavailable — the lock policy is missing or unusable.";
    case PamError.TryAuthFailed:
        return "Authentication is unavailable — the system auth stack failed.";
    case PamError.InternalError:
        return "Authentication is unavailable — the authentication process failed.";
    default:
        return "Authentication is unavailable.";
    }
}

function transition(next, effects) {
    return { next: next, effects: effects || [] };
}
