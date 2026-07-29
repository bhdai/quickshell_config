.pragma library

/**
 * What a key press does to the lock surface's reveal transition.
 *
 * Extracted because there is no display to check it on: "any typing key reveals" and
 * "escape from an empty field returns to rest" are two rules whose edge cases — a bare
 * modifier, a chord, Return, escape with half a password entered — are invisible until
 * someone hits them behind a locked screen.
 */

// Named rather than boolean so a caller cannot invert the decision by accident.
var Action = {
    None: "none",
    Reveal: "reveal",
    ClearPassword: "clearPassword",
    Rest: "rest"
};

// A key that types something a password field would accept. Qt hands out `text` for far
// more than those: a control character for chords (Ctrl-A is 0x01) and for Return, and an
// empty string for modifiers and arrows — so the printable range is the whole test.
function isTypingText(text) {
    if (!text)
        return false;

    for (var i = 0; i < text.length; ++i) {
        var code = text.charCodeAt(i);
        if (code < 0x20 || code === 0x7f)
            return false;
    }
    return true;
}

/**
 * @param revealed whether the authentication area is currently shown
 * @param text the key event's text, exactly as Qt reports it
 * @param escape whether the event's key is Escape
 * @param passwordEmpty whether the entered password is currently empty
 */
function keyAction(revealed, text, escape, passwordEmpty) {
    if (escape) {
        if (!revealed)
            return Action.None;
        // Escape is one control with two steps, so a half-typed password is never carried
        // back into the resting view.
        return passwordEmpty ? Action.Rest : Action.ClearPassword;
    }

    if (!revealed && isTypingText(text))
        return Action.Reveal;

    return Action.None;
}
