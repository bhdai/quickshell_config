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
    assert.equal(treatment(Phase.Absent).copy, "");
});

test("every state but absent is drawn", () => {
    for (const phase of everyPhase.filter(p => p !== Phase.Absent)) {
        const drawn = treatment(phase);

        assert.equal(drawn.visible, true);
        assert.notEqual(drawn.copy, "");
    }
});

test("a rejected scan reads as a refusal rather than as an invitation", () => {
    // The icon is the same one in both — the refusal is about the reader under the
    // finger, not about a different symbol appearing — so colour and motion carry it.
    const armed = treatment(Phase.Armed);
    const rejected = treatment(Phase.Rejected);

    assert.equal(armed.tone, Tone.Neutral);
    assert.equal(rejected.tone, Tone.Error);
    assert.equal(armed.shake, false);
    assert.equal(rejected.shake, true);
    assert.notEqual(armed.copy, rejected.copy);
});

test("nothing but a refusal jolts", () => {
    for (const phase of everyPhase.filter(p => p !== Phase.Rejected)) {
        assert.equal(treatment(phase).shake, false);
    }
});

test("a rejected scan still says to try again", () => {
    // Attempts are unlimited by design, so the copy must not read as a dead end.
    assert.match(treatment(Phase.Rejected).copy, /try again/i);
});

test("there is no state for a win", () => {
    // The grant releases the lock in the same handler that would set one, so a success
    // treatment would be a branch no frame could ever show. Asserted rather than left to
    // a comment: the copy for it is written down in the spec and is easy to add back.
    assert.ok(!everyPhase.includes("recognized"));

    for (const drawn of everyPhase.map(treatment)) {
        assert.doesNotMatch(drawn.copy, /unlocking/i);
    }
});

test("an unrecognised state falls back to drawing nothing", () => {
    assert.deepEqual(treatment("a-fourth-state"), treatment(Phase.Absent));
});

test("the chip draws the bundled fingerprint asset rather than a font glyph", () => {
    // The shipped SVG, colorised onto the palette like the status cluster's icons. It is
    // the same drawing in every state, which is why it is not part of a treatment.
    const [icon] = blocks(affordance, "CustomIcon");

    assert.match(icon, /source: "auth-fingerprint-symbolic"/);
    assert.match(icon, /colorize: true/);
    assert.equal(blocks(affordance, "MaterialSymbol").length, 0);
});

test("the chip's contents are centred by the layout rather than by cross-anchoring", () => {
    // A Row sets only `x`, so its children have to anchor to each other, and the taller
    // icon then hangs above the row's own box and takes the visible content up with it.
    assert.equal(blocks(affordance, "RowLayout").length, 1);
    assert.equal((affordance.match(/Layout\.alignment: Qt\.AlignVCenter/g) ?? []).length, 2);
    assert.doesNotMatch(affordance, /anchors\.verticalCenter: \w+\.verticalCenter/);
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
