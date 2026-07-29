import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { State, Event, Effect, Result, PamError, MessageRole, nextState, passwordAction, errorAction, displayMessage } = loadQmlJs(new URL("../services/LockLogic.js", import.meta.url), ["State", "Event", "Effect", "Result", "PamError", "MessageRole", "nextState", "passwordAction", "errorAction", "displayMessage"]);

const everyState = Object.keys(State).map(k => State[k]);
const lockedStates = [State.Locking, State.Locked, State.Authenticating];

test("a lock request from unlocked raises the lock", () => {
    assert.deepEqual(nextState(State.Unlocked, Event.LockRequested), {
        next: State.Locking,
        effects: [Effect.RaiseLock],
    });
});

test("a lock request is idempotent in every already-locked state", () => {
    for (const state of lockedStates) {
        assert.deepEqual(nextState(state, Event.LockRequested), {
            next: state,
            effects: [],
        });
    }
});

test("secure arms the password context", () => {
    assert.deepEqual(nextState(State.Locking, Event.Secure), {
        next: State.Locked,
        effects: [Effect.Arm],
    });
});

test("secure re-rising while already locked asks to arm again", () => {
    // A preserved hot reload re-raises secure, so the descriptor stays the same
    // and idempotence is the applier's job.
    assert.deepEqual(nextState(State.Locked, Event.Secure), {
        next: State.Locked,
        effects: [Effect.Arm],
    });
});

test("secure losing confirmation disarms and returns to locking", () => {
    assert.deepEqual(nextState(State.Locked, Event.Insecure), {
        next: State.Locking,
        effects: [Effect.Disarm],
    });
});

test("submit from locked sends the response", () => {
    assert.deepEqual(nextState(State.Locked, Event.Submit), {
        next: State.Authenticating,
        effects: [Effect.SendResponse],
    });
});

test("submit outside the locked state sends nothing", () => {
    for (const state of everyState.filter(s => s !== State.Locked)) {
        assert.deepEqual(nextState(state, Event.Submit), {
            next: state,
            effects: [],
        });
    }
});

test("success from authenticating is the only path to the grant", () => {
    assert.deepEqual(nextState(State.Authenticating, Event.Success), {
        next: State.Unlocked,
        effects: [Effect.Grant],
    });
});

test("a second success once the machine has left authenticating is refused", () => {
    for (const state of everyState.filter(s => s !== State.Authenticating)) {
        const transition = nextState(state, Event.Success);
        assert.equal(transition.next, state);
        assert.deepEqual(transition.effects, []);
    }
});

test("a failure returns every locked state to locked", () => {
    for (const state of lockedStates) {
        assert.deepEqual(nextState(state, Event.Failure), {
            next: State.Locked,
            effects: [],
        });
    }
});

test("a compositor denial releases the lock state and disarms", () => {
    for (const state of everyState) {
        assert.deepEqual(nextState(state, Event.Denied), {
            next: State.Unlocked,
            effects: [Effect.Disarm, Effect.ReleaseLock],
        });
    }
});

test("an unknown event changes nothing", () => {
    for (const state of everyState) {
        assert.deepEqual(nextState(state, "no-such-event"), {
            next: state,
            effects: [],
        });
    }
});

test("only a success result unlocks", () => {
    const success = passwordAction(Result.Success, true);
    assert.equal(success.event, Event.Success);
    assert.deepEqual(nextState(State.Authenticating, success.event).effects, [Effect.Grant]);
});

test("no result other than success ever reaches the grant", () => {
    const nonSuccess = [Result.Failed, Result.MaxTries, Result.Error, "a-fifth-result-value"];

    for (const result of nonSuccess) {
        for (const responded of [true, false]) {
            const action = passwordAction(result, responded);

            assert.equal(action.event, Event.Failure);
            assert.ok(!action.effects.includes(Effect.Grant));
            assert.notEqual(action.message, "");

            for (const state of lockedStates) {
                const transition = nextState(state, action.event);
                assert.equal(transition.next, State.Locked);
                assert.ok(!transition.effects.includes(Effect.Grant));
            }
        }
    }
});

test("a failure re-arms only when a response went out this cycle", () => {
    for (const result of [Result.Failed, Result.MaxTries]) {
        assert.deepEqual(passwordAction(result, true).effects, [Effect.Arm]);
    }
});

test("a failure with no response sent this cycle does not re-arm", () => {
    // Starting the context runs the failure-counter preauth, so a locked-out
    // account completes as a failure before anything is typed. Re-arming there
    // spins, hammering the counter.
    for (const result of [Result.Failed, Result.MaxTries, Result.Error, "a-fifth-result-value"]) {
        assert.deepEqual(passwordAction(result, false).effects, []);
    }
});

test("too many tries reads differently from one mistyped password", () => {
    const failed = passwordAction(Result.Failed, true);
    const maxTries = passwordAction(Result.MaxTries, true);

    assert.equal(failed.messageRole, MessageRole.Error);
    assert.equal(maxTries.messageRole, MessageRole.Warning);
    assert.notEqual(failed.message, maxTries.message);
});

test("an error result blames the service rather than the password", () => {
    const action = passwordAction(Result.Error, true);
    assert.equal(action.messageRole, MessageRole.Unavailable);
});

test("an unrecognised result fails closed as unavailable", () => {
    const action = passwordAction("a-fifth-result-value", true);
    assert.equal(action.event, Event.Failure);
    assert.equal(action.messageRole, MessageRole.Unavailable);
});

test("a success carries no message to display", () => {
    const action = passwordAction(Result.Success, true);
    assert.deepEqual(action.effects, []);
    assert.equal(action.message, "");
    assert.equal(action.messageRole, MessageRole.None);
});

test("every pam error is diagnostic only and leaves the machine locked", () => {
    const errors = [PamError.StartFailed, PamError.TryAuthFailed, PamError.InternalError, "a-fourth-error-value"];

    for (const pamError of errors) {
        const action = errorAction(pamError);

        assert.equal(action.event, null);
        assert.deepEqual(action.effects, []);
        assert.equal(action.messageRole, MessageRole.Unavailable);
        assert.notEqual(action.message, "");

        // The completion that always follows is what actually transitions, and
        // it is a failure, so every error value ends up back at Locked.
        for (const state of lockedStates) {
            assert.equal(nextState(state, passwordAction(Result.Error, true).event).next, State.Locked);
        }
    }
});

// Account lockout has no result code of its own — pam_faillock refuses with a plain failure
// and says why only in the text it sent during the conversation. "Password incorrect. Try
// again." painted over that is the one outcome where the user retypes forever and never
// learns that retyping is not the problem.
test("what pam actually said outranks the generic copy for the result", () => {
    const rejection = passwordAction(Result.Failed, true);
    const lockout = "Account locked due to 3 failed logins";

    assert.deepEqual(displayMessage(rejection, lockout, ""), {
        message: lockout,
        messageRole: rejection.messageRole,
    });
});

test("with nothing said, the generic copy for the result stands", () => {
    for (const result of [Result.Failed, Result.MaxTries, Result.Error]) {
        const action = passwordAction(result, true);

        assert.deepEqual(displayMessage(action, "", ""), {
            message: action.message,
            messageRole: action.messageRole,
        });
    }
});

test("a pam error describes itself where the conversation said nothing", () => {
    const action = passwordAction(Result.Error, true);
    const diagnostic = errorAction(PamError.StartFailed).message;

    assert.equal(displayMessage(action, "", diagnostic).message, diagnostic);
});

// The module's own words beat our description of the machinery: "the system auth stack
// failed" is what we can infer, the message is what the stack itself reported.
test("the conversation outranks the pam error too", () => {
    const action = passwordAction(Result.Error, true);

    assert.equal(displayMessage(action, "Account locked", errorAction(PamError.TryAuthFailed).message).message, "Account locked");
});

test("a success displays nothing", () => {
    const success = passwordAction(Result.Success, true);

    assert.deepEqual(displayMessage(success, "", ""), {
        message: "",
        messageRole: MessageRole.None,
    });
});

test("each pam error is described distinctly", () => {
    const messages = [PamError.StartFailed, PamError.TryAuthFailed, PamError.InternalError].map(e => errorAction(e).message);

    assert.equal(new Set(messages).size, messages.length);
});
