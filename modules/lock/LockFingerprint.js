.pragma library

/**
 * How the fingerprint affordance draws each state the lock reports.
 *
 * Driven by state names rather than by what the module said, and that is the point: the
 * message text carries the reader's internal device name, and mapping known strings would
 * mean matching *translated* output, which breaks silently outside an English locale. The
 * module also carries swipe-sensor copy that is dead text on this press-type reader. So
 * every word here is this shell's own.
 *
 * The icon is not part of a treatment because it never changes. Every state draws the same
 * fingerprint, which is what keeps a refusal about the reader under the user's finger
 * rather than about a different symbol appearing in its place — colour and motion are what
 * carry it.
 */

// The same strings as LockLogic.Fingerprint, written out again because a .pragma library
// cannot import another. tests/lock-fingerprint.test.mjs asserts the two sets match, so a
// state added there and not here fails rather than silently rendering nothing.
var Phase = {
    Absent: "absent",
    Armed: "armed",
    Rejected: "rejected"
};

// Colour roles rather than colours: the QML maps these onto Appearance, which is where
// every colour on this screen comes from.
var Tone = {
    Neutral: "neutral",
    Error: "error"
};

/**
 * @param phase a LockLogic.Fingerprint value
 *
 * `visible` is false only for Absent, which covers no reader, no enrolment, a reader
 * unplugged mid-lock, and the permanent stop alike — the chip goes away rather than
 * greying out, because a disabled control offers something that cannot happen.
 */
function treatment(phase) {
    switch (phase) {
    case Phase.Armed:
        return {
            visible: true,
            tone: Tone.Neutral,
            shake: false,
            copy: "Touch the fingerprint sensor"
        };

    case Phase.Rejected:
        return {
            visible: true,
            tone: Tone.Error,
            shake: true,
            // Attempts are unlimited, so this says what happened without reading as a
            // dead end. It never appears in the password message area: that area has to
            // stay readable for the account-lockout text, which the result code cannot
            // carry and which an unrelated touch must not be able to paint over.
            copy: "Fingerprint not recognized. Try again."
        };

    default:
        return {
            visible: false,
            tone: Tone.Neutral,
            shake: false,
            copy: ""
        };
    }
}
