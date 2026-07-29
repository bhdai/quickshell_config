.pragma library

/**
 * How the fingerprint affordance draws each state the lock reports.
 *
 * Driven by state names rather than by what the module said, and that is the point: the
 * message text carries the reader's internal device name, and mapping known strings would
 * mean matching *translated* output, which breaks silently outside an English locale. The
 * module also carries swipe-sensor copy that is dead text on this press-type reader. So
 * every word here is this shell's own.
 */

// The same strings as LockLogic.Fingerprint, written out again because a .pragma library
// cannot import another. tests/lock-fingerprint.test.mjs asserts the two sets match, so a
// state added there and not here fails rather than silently rendering nothing.
var Phase = {
    Absent: "absent",
    Armed: "armed",
    Rejected: "rejected",
    Recognized: "recognized"
};

// Colour roles rather than colours: the QML maps these onto Appearance, which is where
// every colour on this screen comes from.
var Tone = {
    Neutral: "neutral",
    Error: "error",
    Success: "success"
};

/**
 * @param phase a LockLogic.Fingerprint value
 *
 * `visible` is false only for Absent, which covers no reader, no enrolment, a reader
 * unplugged mid-lock, and the permanent stop alike — the chip goes away rather than
 * greying out, because a disabled control offers something that cannot happen.
 *
 * The invitation and the refusal share an icon, which is the approved prototype's
 * treatment: what separates them is the chip going red and jolting, so the refusal is
 * still about the reader the user is touching rather than a different symbol appearing in
 * its place.
 */
function treatment(phase) {
    switch (phase) {
    case Phase.Armed:
        return {
            visible: true,
            tone: Tone.Neutral,
            icon: "fingerprint",
            shake: false,
            copy: "Touch the fingerprint sensor"
        };

    case Phase.Rejected:
        return {
            visible: true,
            tone: Tone.Error,
            icon: "fingerprint",
            shake: true,
            // Attempts are unlimited, so this says what happened without reading as a
            // dead end. It never appears in the password message area: that area has to
            // stay readable for the account-lockout text, which the result code cannot
            // carry and which an unrelated touch must not be able to paint over.
            copy: "Fingerprint not recognized. Try again."
        };

    case Phase.Recognized:
        return {
            visible: true,
            tone: Tone.Success,
            icon: "check_circle",
            shake: false,
            copy: "Fingerprint recognized. Unlocking…"
        };

    default:
        return {
            visible: false,
            tone: Tone.Neutral,
            icon: "fingerprint_off",
            shake: false,
            copy: ""
        };
    }
}
