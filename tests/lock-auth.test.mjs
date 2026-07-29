import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { State, Tone, Role, fieldState, treatment } = loadQmlJs(
    new URL("../modules/lock/LockAuth.js", import.meta.url),
    ["State", "Tone", "Role", "fieldState", "treatment"],
);

const { MessageRole } = loadQmlJs(new URL("../services/LockLogic.js", import.meta.url), ["MessageRole"]);

const failureRoles = [Role.Error, Role.Warning, Role.Unavailable];
const everyState = Object.keys(State).map(key => State[key]);

test("an empty field with nothing to report is idle", () => {
    assert.equal(fieldState(false, Role.None, false), State.Idle);
});

test("entered text is typing", () => {
    assert.equal(fieldState(false, Role.None, true), State.Typing);
});

test("a response in flight outranks everything else", () => {
    for (const role of [Role.None].concat(failureRoles)) {
        for (const hasText of [false, true]) {
            assert.equal(fieldState(true, role, hasText), State.Authenticating);
        }
    }
});

test("each failure role has a state of its own", () => {
    assert.equal(fieldState(false, Role.Error, false), State.Rejected);
    assert.equal(fieldState(false, Role.Warning, false), State.TooManyAttempts);
    assert.equal(fieldState(false, Role.Unavailable, false), State.Unavailable);
});

// The message is deliberately not on a timer, so it is still on screen when the user starts
// over. A field that stays red under the characters being typed into it would say the new
// attempt has already failed.
test("typing again returns the field to ordinary dots while the message stays put", () => {
    for (const role of failureRoles) {
        assert.equal(fieldState(false, role, true), State.Typing);
    }
});

test("the three failures look like three different things", () => {
    const treatments = failureRoles.map(role => treatment(fieldState(false, role, false)));
    const looks = treatments.map(({ tone, filled, fieldIcon, statusIcon }) => `${tone}/${filled}/${fieldIcon}/${statusIcon}`);

    assert.equal(new Set(looks).size, looks.length);
});

// One mistyped password is the only failure the user can fix by trying again immediately,
// and the shake is what says so. Shaking at a lockout or a dead service would tell them to
// retype, which is exactly the wrong instruction.
test("only a rejected password shakes", () => {
    assert.equal(treatment(State.Rejected).shake, true);

    for (const state of everyState.filter(s => s !== State.Rejected)) {
        assert.equal(treatment(state).shake, false);
    }
});

test("a lockout is warned about rather than blamed on the password", () => {
    assert.equal(treatment(State.TooManyAttempts).tone, Tone.Warning);
    assert.notEqual(treatment(State.TooManyAttempts).tone, treatment(State.Rejected).tone);
});

test("a service failure carries the strongest treatment and an icon about the machine", () => {
    const unavailable = treatment(State.Unavailable);

    assert.equal(unavailable.tone, Tone.Unavailable);
    assert.equal(unavailable.filled, true);
    assert.notEqual(unavailable.fieldIcon, treatment(State.Rejected).fieldIcon);
    assert.notEqual(unavailable.submitIcon, treatment(State.Rejected).submitIcon);
});

test("only the authenticating state runs the progress treatment", () => {
    assert.equal(treatment(State.Authenticating).spin, true);
    assert.equal(treatment(State.Authenticating).tone, Tone.Progress);

    for (const state of everyState.filter(s => s !== State.Authenticating)) {
        assert.equal(treatment(state).spin, false);
    }
});

test("idle and typing are quiet", () => {
    for (const state of [State.Idle, State.Typing]) {
        assert.equal(treatment(state).tone, Tone.Neutral);
        assert.equal(treatment(state).filled, false);
    }
});

// The idle, typing and authenticating copy has no other home; the failure copy comes from
// the conversation and its result code, and duplicating it here would be a second source of
// the same sentence.
test("every state that has no message of its own carries its own copy", () => {
    for (const state of [State.Idle, State.Typing, State.Authenticating]) {
        assert.notEqual(treatment(state).copy, "");
    }
});

test("every treatment names an icon for the field, the status line and the confirm control", () => {
    for (const state of everyState) {
        const { fieldIcon, statusIcon, submitIcon } = treatment(state);

        for (const icon of [fieldIcon, statusIcon, submitIcon]) {
            assert.match(icon, /^[a-z_]+$/);
        }
    }
});

test("an unrecognised state is treated as idle", () => {
    assert.deepEqual(treatment("a-seventh-state"), treatment(State.Idle));
});

// The two enums are string-identical by hand: a .pragma library cannot import another, so
// nothing but this stops a role added to LockLogic from silently falling through to idle.
test("every message role the lock can produce is a state here", () => {
    const roles = Object.keys(MessageRole).map(key => MessageRole[key]);

    assert.deepEqual(roles.slice().sort(), Object.keys(Role).map(key => Role[key]).sort());

    for (const role of roles.filter(r => r !== MessageRole.None)) {
        assert.notEqual(fieldState(false, role, false), State.Idle);
    }
});
