import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { Action, keyAction } = loadQmlJs(
    new URL("../modules/lock/LockReveal.js", import.meta.url),
    ["Action", "keyAction"],
);

// The four arguments in the order the surface passes them, named so a test reads as the
// situation it describes rather than as a row of positional booleans.
function press({ revealed = false, text = "", escape = false, passwordEmpty = true } = {}) {
    return keyAction(revealed, text, escape, passwordEmpty);
}

test("a printable character at rest reveals the authentication area", () => {
    assert.equal(press({ text: "a" }), Action.Reveal);
    assert.equal(press({ text: "7" }), Action.Reveal);
    assert.equal(press({ text: " " }), Action.Reveal);
    assert.equal(press({ text: "é" }), Action.Reveal);
});

// Qt reports text for far more than the typing keys: a control character for chords and
// for Return, an empty string for modifiers and arrows. Revealing on those would fire on
// a stray Shift press, which is what "any typing key" is not.
test("a key that types nothing leaves the resting view alone", () => {
    assert.equal(press({ text: "" }), Action.None);
    assert.equal(press({ text: "\r" }), Action.None);
    assert.equal(press({ text: "\b" }), Action.None);
    assert.equal(press({ text: "" }), Action.None);
    assert.equal(press({ text: "" }), Action.None);
});

test("typing while already revealed changes nothing — the field has the character", () => {
    assert.equal(press({ revealed: true, text: "a" }), Action.None);
});

test("escape from an empty field returns to rest", () => {
    assert.equal(press({ revealed: true, escape: true, passwordEmpty: true }), Action.Rest);
});

// Escape is one control with two steps: it empties the field before it puts the prompt
// away, so a half-typed password is never carried back into the resting view.
test("escape with entered text clears the text rather than dismissing", () => {
    assert.equal(press({ revealed: true, escape: true, passwordEmpty: false }), Action.ClearPassword);
});

test("escape at rest does nothing — there is nothing to dismiss", () => {
    assert.equal(press({ revealed: false, escape: true }), Action.None);
});

// Escape arrives with text "", which the printable test would have to reject on its
// own for the key code not to be consulted first.
test("escape is decided by the key, not by the text it carries", () => {
    assert.equal(press({ revealed: true, text: "", escape: true }), Action.Rest);
});
