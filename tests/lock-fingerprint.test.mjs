import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";
import { blocks, read } from "./qml-source.mjs";

const { Phase, Tone, treatment } = loadQmlJs(new URL("../modules/lock/LockFingerprint.js", import.meta.url), ["Phase", "Tone", "treatment"]);
const { Fingerprint } = loadQmlJs(new URL("../services/LockLogic.js", import.meta.url), ["Fingerprint"]);

const everyPhase = Object.keys(Phase).map(k => Phase[k]);

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockService = read(repoRoot, "services", "Lock.qml");
const surface = read(repoRoot, "modules", "lock", "LockSurface.qml");
const affordance = read(repoRoot, "modules", "lock", "LockFingerprint.qml");

const [fingerprintContext] = blocks(lockService, "PamContext").filter(context => /quickshell-fprint/.test(context));

// The affordance is fed straight from Lock.fingerprintState, so a state added to the
// singleton's enum and not to this one would silently render as nothing at all — which
// on this component means the reader looks broken rather than looking wrong.
test("every state the lock can report has a treatment here", () => {
    const reported = Object.keys(Fingerprint).map(k => Fingerprint[k]);

    assert.deepEqual(new Set(reported), new Set(everyPhase));
});

test("absent renders nothing", () => {
    assert.equal(treatment(Phase.Absent).visible, false);
});

test("no reader and no enrolment leave nothing on screen to explain", () => {
    // Absent, not disabled: a greyed-out reader on a machine that has none is an
    // affordance offering something that cannot happen.
    const absent = treatment(Phase.Absent);

    assert.equal(absent.copy, "");
    assert.equal(absent.icon, "");
});

test("every state but absent is drawn", () => {
    for (const phase of everyPhase.filter(p => p !== Phase.Absent)) {
        const drawn = treatment(phase);

        assert.equal(drawn.visible, true);
        assert.notEqual(drawn.copy, "");
        assert.notEqual(drawn.icon, "");
    }
});

test("a rejected scan reads as a refusal rather than as an invitation", () => {
    const armed = treatment(Phase.Armed);
    const rejected = treatment(Phase.Rejected);

    assert.equal(armed.tone, Tone.Neutral);
    assert.equal(rejected.tone, Tone.Error);
    assert.notEqual(armed.icon, rejected.icon);
    assert.notEqual(armed.copy, rejected.copy);
});

test("a rejected scan still says to try again", () => {
    // Attempts are unlimited by design, so the copy must not read as a dead end.
    assert.match(treatment(Phase.Rejected).copy, /try again/i);
});

test("a recognised scan says the machine is opening", () => {
    const recognized = treatment(Phase.Recognized);

    assert.equal(recognized.tone, Tone.Success);
    assert.match(recognized.copy, /unlocking/i);
});

test("the three drawn states are three distinct treatments", () => {
    const looks = everyPhase.filter(p => p !== Phase.Absent).map(p => {
        const drawn = treatment(p);
        return `${drawn.tone}/${drawn.icon}`;
    });

    assert.equal(new Set(looks).size, looks.length);
});

test("an unrecognised state falls back to drawing nothing", () => {
    assert.deepEqual(treatment("a-fifth-state"), treatment(Phase.Absent));
});

// The rest is wiring, and it is asserted here because none of it is visible on a screen:
// a fingerprint context that quietly disturbed the password one would look exactly like a
// working lock right up to the touch that lost someone their half-typed password.

test("the two factors are two contexts against two policies", () => {
    const configs = blocks(lockService, "PamContext").map(context => context.match(/config: "([^"]+)"/)[1]);

    assert.deepEqual(configs.sort(), ["quickshell-fprint", "quickshell-lock"]);
});

test("a fingerprint outcome never touches the password conversation", () => {
    // Not the field, not the message area, not the prompt state, and not the response
    // bookkeeping. The two meet only at the moment one of them wins.
    assert.doesNotMatch(fingerprintContext, /priv\.message|priv\.messageRole|priv\.promptReady|priv\.respondedThisCycle|root\.password|pam\./);
});

test("the fingerprint context never sends a response", () => {
    // Its stack has no response-requiring prompt, and there is no password here to send.
    assert.doesNotMatch(fingerprintContext, /respond\(/);
});

test("the reader is re-armed off a timer rather than from inside the completion", () => {
    // Restarting a context from its own completion handler is reentrancy resting on
    // emission order, and the delay is what turns a misclassified stop into a few forks a
    // second — visible in the journal — rather than a wedged laptop behind a locked screen.
    assert.doesNotMatch(fingerprintContext, /fingerprint\.start\(\)/);

    const [request] = blocks(lockService, "function requestFingerprintArm(): void");
    assert.match(request, /fingerprintArm\.restart\(\)/);

    const [arm] = blocks(lockService, "function armFingerprint(): void");
    assert.match(arm, /fingerprint\.start\(\)/);
});

test("a stopped reader cannot be re-armed for the rest of the lock", () => {
    // Both doors, because the arm request and the arm itself are reachable separately —
    // one from an effect, one from the timer that effect started.
    for (const name of ["function requestFingerprintArm(): void", "function armFingerprint(): void"]) {
        assert.match(blocks(lockService, name)[0], /priv\.fingerprintStopped/);
    }
});

test("a win clears the password before the lock is released", () => {
    const [grant] = blocks(lockService, "function grant(): void");

    assert.ok(grant.indexOf('root.password = ""') < grant.indexOf("persist.locked = false"));
    assert.match(grant, /priv\.disarmFingerprint\(\)/);
});

test("the affordance is instantiated once and reads only the state the lock reports", () => {
    const instantiations = blocks(surface, "LockFingerprint");

    assert.equal(instantiations.length, 1);
    assert.match(instantiations[0], /phase: Lock\.fingerprintState/);

    // It reads no singleton of its own, which is what keeps the view layer's whole reach
    // in one place and lets the harness walk every state with no reader behind it.
    assert.doesNotMatch(affordance, /\bLock\./);
});
