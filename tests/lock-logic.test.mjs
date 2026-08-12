import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { State, Event, Effect, Result, PamError, MessageRole, Fingerprint, nextState, passwordAction, errorAction, displayMessage, fingerprintAction, fingerprintState, fingerprintRetryDelay } = loadQmlJs(new URL("../services/LockLogic.js", import.meta.url), ["State", "Event", "Effect", "Result", "PamError", "MessageRole", "Fingerprint", "nextState", "passwordAction", "errorAction", "displayMessage", "fingerprintAction", "fingerprintState", "fingerprintRetryDelay"]);

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

test("secure arms both factors", () => {
    // Not `locked`: before the compositor confirms it stopped routing input to normal
    // clients, a touch on the reader would authenticate against a screen that is not yet
    // covering the desktop.
    assert.deepEqual(nextState(State.Locking, Event.Secure), {
        next: State.Locked,
        effects: [Effect.Arm, Effect.ArmFingerprint],
    });
});

test("secure re-rising while already locked asks to arm again", () => {
    // A preserved hot reload re-raises secure, so the descriptor stays the same
    // and idempotence is the applier's job.
    assert.deepEqual(nextState(State.Locked, Event.Secure), {
        next: State.Locked,
        effects: [Effect.Arm, Effect.ArmFingerprint],
    });
});

test("secure losing confirmation disarms both factors and returns to locking", () => {
    assert.deepEqual(nextState(State.Locked, Event.Insecure), {
        next: State.Locking,
        effects: [Effect.Disarm, Effect.DisarmFingerprint],
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

test("a compositor denial releases the lock state and disarms both factors", () => {
    for (const state of everyState) {
        assert.deepEqual(nextState(state, Event.Denied), {
            next: State.Unlocked,
            effects: [Effect.Disarm, Effect.DisarmFingerprint, Effect.ReleaseLock],
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

test("a matched finger unlocks from either state a scan can complete in", () => {
    const action = fingerprintAction(Result.Success, true);
    assert.equal(action.event, Event.FingerprintSuccess);

    // The password machine may be resting or mid-authentication when the finger lands;
    // both are a genuine PAM success against the fingerprint policy.
    for (const state of [State.Locked, State.Authenticating]) {
        assert.deepEqual(nextState(state, Event.FingerprintSuccess), {
            next: State.Unlocked,
            effects: [Effect.Grant],
        });
    }
});

test("a fingerprint success outside a confirmed lock is refused", () => {
    // Locking means the compositor has not confirmed it is covering the desktop, and
    // Unlocked means something already won. Neither may be unlocked again.
    for (const state of [State.Unlocked, State.Locking]) {
        assert.deepEqual(nextState(state, Event.FingerprintSuccess), {
            next: state,
            effects: [],
        });
    }
});

test("no fingerprint result other than success reaches the grant", () => {
    const nonSuccess = [Result.Failed, Result.MaxTries, Result.Error, "a-fifth-result-value"];

    for (const result of nonSuccess) {
        for (const sawMessage of [true, false]) {
            const action = fingerprintAction(result, sawMessage);

            assert.equal(action.event, null);
            assert.ok(!action.effects.includes(Effect.Grant));
        }
    }
});

test("a non-matching finger re-arms and stays retryable", () => {
    // Under max-tries=1 the module reports MaxTries for "that finger did not match",
    // and there is deliberately no attempt cap in QML: a counter here would smuggle
    // the password lockout back into a stack that was kept free of it on purpose.
    const action = fingerprintAction(Result.MaxTries, true);

    assert.ok(action.effects.includes(Effect.ArmFingerprint));
    assert.equal(action.feedback, Fingerprint.Rejected);
});

test("a non-matching finger reveals the auth area", () => {
    // The chip renders inside the revealed tier, so a refusal from the resting view is
    // drawn at zero opacity and the finger reads as a dead sensor. Revealing puts the
    // shake and the copy where they are legible, and lands the user on the factor that
    // still works — the password — rather than reporting a dead end they cannot act on.
    assert.ok(fingerprintAction(Result.MaxTries, true).effects.includes(Effect.RevealAuth));
});

test("only a refused finger reveals the auth area", () => {
    // A win tears the screen down and every other outcome is the reader failing rather
    // than the user being told no, so nothing else may open the prompt. A reader that
    // vanishes must not pop the password field open on a screen nobody is standing at.
    const others = [Result.Success, Result.Failed, Result.Error, "a-fifth-result-value"];

    for (const result of others) {
        for (const sawMessage of [true, false]) {
            assert.ok(!fingerprintAction(result, sawMessage).effects.includes(Effect.RevealAuth), `${result} revealed`);
        }
    }
});

test("an error with no message this cycle stops the reader", () => {
    // The fork loop. Error conflates "you took thirty seconds" with "there is no
    // reader", and with no reader the module returns instantly — so re-arming blindly
    // spins behind a locked screen. Stopping is what forbids the immediate re-arm; the
    // applier still spends the backoff budget below before the stop becomes permanent.
    const action = fingerprintAction(Result.Error, false);

    assert.deepEqual(action.effects, [Effect.StopFingerprint]);
    assert.ok(!action.effects.includes(Effect.ArmFingerprint));
    assert.equal(action.feedback, Fingerprint.Absent);
});

test("an error with a message this cycle re-arms", () => {
    // A message proves the module claimed the reader, which leaves the timeout as the
    // only thing the error can have been. Arrival is the discriminator and not content:
    // the timeout string is syslog-only and never reaches the message property.
    const action = fingerprintAction(Result.Error, true);

    assert.deepEqual(action.effects, [Effect.ArmFingerprint]);
});

test("a reader unplugged mid-scan costs exactly one wasted attempt", () => {
    // The message for the pending scan already arrived, so that cycle retries; the
    // retry claims nothing and gets no message, and that one stops.
    assert.deepEqual(fingerprintAction(Result.Error, true).effects, [Effect.ArmFingerprint]);
    assert.deepEqual(fingerprintAction(Result.Error, false).effects, [Effect.StopFingerprint]);
});

test("an unrecognised fingerprint result stops quietly", () => {
    for (const sawMessage of [true, false]) {
        const action = fingerprintAction("a-fifth-result-value", sawMessage);

        assert.deepEqual(action.effects, [Effect.StopFingerprint]);
        assert.equal(action.feedback, Fingerprint.Absent);
    }
});

test("a plain fingerprint failure stops rather than retrying", () => {
    assert.deepEqual(fingerprintAction(Result.Failed, true).effects, [Effect.StopFingerprint]);
});

test("no fingerprint outcome touches the password context", () => {
    const passwordEffects = [Effect.Arm, Effect.Disarm, Effect.SendResponse, Effect.ReleaseLock];
    const results = [Result.Success, Result.Failed, Result.MaxTries, Result.Error, "a-fifth-result-value"];

    for (const result of results) {
        for (const sawMessage of [true, false]) {
            for (const effect of fingerprintAction(result, sawMessage).effects) {
                assert.ok(!passwordEffects.includes(effect), `${result} produced ${effect}`);
            }
        }
    }
});

test("a stopped reader is retried on a backoff before it is given up on", () => {
    // Measured on this machine: a release that timed out wedged the Prometheus, which
    // then fell off the USB bus and re-enumerated about a second later. A stop that was
    // permanent on the first refusal left the chip absent for the rest of that lock even
    // though the reader was healthy again well within it.
    const delays = [0, 1, 2].map(attempt => fingerprintRetryDelay(attempt));

    assert.ok(delays.every(delay => delay > 0), `expected retries, got ${delays}`);
    for (let i = 1; i < delays.length; i++) {
        assert.ok(delays[i] > delays[i - 1], `attempt ${i} must wait longer than ${i - 1}`);
    }
});

test("the fingerprint backoff is finite", () => {
    // The budget is what keeps a genuinely missing quickshell-fprint policy from
    // retrying forever behind a locked screen — the fork loop, slowed down but still a
    // loop. A negative delay is the applier's signal to latch the stop for good.
    const exhausted = fingerprintRetryDelay(4);

    assert.ok(exhausted < 0, `expected exhaustion at attempt 4, got ${exhausted}`);
    assert.ok(fingerprintRetryDelay(100) < 0);
});

test("the fingerprint backoff outlasts a reader re-enumerating", () => {
    // The whole point of the budget: the observed gap between the reader disconnecting
    // and fprintd seeing it again was about a second, so the schedule has to still be
    // retrying well past that or it buys nothing.
    let total = 0;
    for (let attempt = 0; fingerprintRetryDelay(attempt) > 0; attempt++) {
        total += fingerprintRetryDelay(attempt);
    }

    assert.ok(total >= 10000, `budget of ${total}ms is too short to outlast a re-enumeration`);
});

test("the fingerprint backoff outlasts an fprintd that enumerated no reader", () => {
    // After a resume the adversary is fprintd rather than the bus. It looks for readers
    // once, at startup, and serves that answer for its whole life — so an instance
    // D-Bus-activated while the reader is still re-enumerating has an empty device list
    // until it idle-exits thirty seconds later. Every retry inside that window reaches
    // that same instance and is refused, and each one restarts its idle timer, so a
    // schedule of short waits cannot outlive the thing refusing it however many it has.
    // One wait has to outlast the daemon, or the budget only ever confirms the same
    // corpse.
    //
    // Observed 2026-08-11 20:14: lid opened, the frozen arm fired and started fprintd
    // 0.3s later against a reader still 1.2s from ready, the budget was spent at t+17.7s,
    // and the empty instance exited at t+30.5s — thirteen seconds after the shell had
    // given up. The chip was absent for the rest of that lock.
    const fprintdIdleExit = 30000;

    let longest = 0;
    for (let attempt = 0; fingerprintRetryDelay(attempt) > 0; attempt++) {
        longest = Math.max(longest, fingerprintRetryDelay(attempt));
    }

    assert.ok(longest > fprintdIdleExit, `longest wait of ${longest}ms cannot outlive a ${fprintdIdleExit}ms daemon`);
});

test("the affordance stays absent until a message has proven the reader", () => {
    assert.equal(fingerprintState(false, false, Fingerprint.Absent), Fingerprint.Absent);
    assert.equal(fingerprintState(true, false, Fingerprint.Absent), Fingerprint.Armed);
});

test("a stopped reader is absent however it was proven", () => {
    for (const feedback of Object.keys(Fingerprint).map(k => Fingerprint[k])) {
        assert.equal(fingerprintState(true, true, feedback), Fingerprint.Absent);
    }
});

test("feedback shows through only while the reader is live", () => {
    assert.equal(fingerprintState(true, false, Fingerprint.Rejected), Fingerprint.Rejected);
    assert.equal(fingerprintState(true, false, Fingerprint.Armed), Fingerprint.Armed);
});

test("a win has no feedback of its own to leave behind", () => {
    // The grant releases the lock in the same handler, so there is no frame in which a
    // "recognized" treatment could be drawn — and a state nothing can show is a branch
    // the next reader would have to prove unreachable.
    assert.equal(fingerprintAction(Result.Success, true).feedback, Fingerprint.Armed);
    assert.ok(!Object.keys(Fingerprint).map(k => Fingerprint[k]).includes("recognized"));
});
