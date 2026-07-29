.pragma library

/**
 * Which of the six password interaction treatments the prompt is showing, and what that
 * treatment looks like.
 *
 * Extracted for the same reason LockReveal.js is: there is no display in CI, and the one
 * property that matters here is a visual one. The three failures call for three different
 * actions — a mistyped password means try again, a lockout means wait, a service failure
 * means go and look at the machine rather than at your own typing — so three treatments
 * that drifted into looking alike would give the same instruction for all three.
 */

var State = {
    Idle: "idle",
    Typing: "typing",
    Authenticating: "authenticating",
    Rejected: "rejected",
    TooManyAttempts: "tooManyAttempts",
    Unavailable: "unavailable"
};

// Colour roles rather than colours: the QML maps these onto Appearance, which is where
// every colour on this screen comes from.
var Tone = {
    Neutral: "neutral",
    Progress: "progress",
    Error: "error",
    Warning: "warning",
    Unavailable: "unavailable"
};

// The same strings as LockLogic.MessageRole, written out again because a .pragma library
// cannot import another. tests/lock-auth.test.mjs feeds that enum through this one, so a
// role added there and not here fails rather than silently falling through to idle.
var Role = {
    None: "none",
    Error: "error",
    Warning: "warning",
    Unavailable: "unavailable"
};

/**
 * @param authenticating whether a response is in flight
 * @param messageRole the role of the message on screen (LockLogic.MessageRole)
 * @param hasText whether anything is entered
 *
 * Typing outranks the failure roles. The message is deliberately not on a timer, so it is
 * still there when the user starts over; a field that stayed red under the characters being
 * typed into it would say the new attempt had already failed.
 */
function fieldState(authenticating, messageRole, hasText) {
    if (authenticating)
        return State.Authenticating;
    if (hasText)
        return State.Typing;

    switch (messageRole) {
    case Role.Error:
        return State.Rejected;
    case Role.Warning:
        return State.TooManyAttempts;
    case Role.Unavailable:
        return State.Unavailable;
    default:
        return State.Idle;
    }
}

/**
 * How a state renders: `tone` and `filled` are the colour treatment, `copy` is the status
 * line for the states that have no message from PAM behind them, and the icons name Material
 * Symbols. The failure states carry no copy of their own — theirs comes from the result
 * code, and a second copy of the same sentence here is a second thing to keep in step.
 */
function treatment(state) {
    switch (state) {
    case State.Typing:
        return {
            tone: Tone.Neutral,
            filled: false,
            shake: false,
            spin: false,
            fieldIcon: "lock",
            statusIcon: "lock",
            submitIcon: "arrow_forward",
            copy: "Press Enter or use the arrow to unlock"
        };

    case State.Authenticating:
        return {
            tone: Tone.Progress,
            filled: false,
            shake: false,
            spin: true,
            fieldIcon: "lock_clock",
            statusIcon: "progress_activity",
            submitIcon: "progress_activity",
            copy: "Checking password…"
        };

    case State.Rejected:
        return {
            tone: Tone.Error,
            filled: false,
            shake: true,
            spin: false,
            fieldIcon: "lock",
            statusIcon: "error",
            submitIcon: "arrow_forward",
            copy: ""
        };

    case State.TooManyAttempts:
        return {
            tone: Tone.Warning,
            filled: true,
            shake: false,
            spin: false,
            fieldIcon: "lock_clock",
            statusIcon: "timer",
            submitIcon: "arrow_forward",
            copy: ""
        };

    case State.Unavailable:
        return {
            tone: Tone.Unavailable,
            filled: true,
            shake: false,
            spin: false,
            fieldIcon: "lock_reset",
            statusIcon: "build_circle",
            submitIcon: "refresh",
            copy: ""
        };

    default:
        return {
            tone: Tone.Neutral,
            filled: false,
            shake: false,
            spin: false,
            fieldIcon: "lock",
            statusIcon: "lock",
            submitIcon: "arrow_forward",
            copy: "Enter your password"
        };
    }
}
