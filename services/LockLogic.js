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
        return transition(State.Locked, [Effect.Arm]);

    case Event.Insecure:
        return state === State.Unlocked ? transition(state, [Effect.Disarm]) : transition(State.Locking, [Effect.Disarm]);

    case Event.Submit:
        return state === State.Locked ? transition(State.Authenticating, [Effect.SendResponse]) : transition(state);

    case Event.Success:
        // The only edge that produces a grant. A success arriving in any other
        // state is a late or duplicate signal and must not unlock.
        return state === State.Authenticating ? transition(State.Unlocked, [Effect.Grant]) : transition(state);

    case Event.Failure:
        return state === State.Unlocked ? transition(state) : transition(State.Locked);

    case Event.Denied:
        // The compositor refused or dropped the lock. Nothing authenticated, so
        // the persisted request is released rather than granted.
        return transition(State.Unlocked, [Effect.Disarm, Effect.ReleaseLock]);

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
