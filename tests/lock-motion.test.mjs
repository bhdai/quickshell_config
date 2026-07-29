import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockDir = path.join(repoRoot, "modules", "lock");
const appearance = read(repoRoot, "modules", "common", "Appearance.qml");
const surface = read(lockDir, "LockSurface.qml");
const profile = read(lockDir, "LockProfile.qml");

function tier(name) {
    const [declaration] = blocks(appearance, `readonly property QtObject ${name}: QtObject`);
    assert.ok(declaration, `Appearance.animation.${name} is not declared`);
    return declaration;
}

function duration(token, name = "duration") {
    const declaration = token.match(new RegExp(`readonly property int ${name}: (\\d+)`));
    assert.ok(declaration, `the token declares no ${name}`);
    return Number(declaration[1]);
}

function curve(token) {
    const declaration = token.match(/readonly property var bezierCurve: \[([^\]]*)\]/);
    assert.ok(declaration, "the token declares no bezierCurve");
    return declaration[1].split(",").map(Number);
}

// The innermost `Item { … }` around a piece of the surface, so a test can ask what the
// element carrying an animation actually wraps without depending on nesting depth.
function enclosingItem(source, needle) {
    const containing = blocks(source, "Item").filter(block => block.includes(needle));
    assert.ok(containing.length, `nothing encloses ${needle}`);
    return containing.reduce((smallest, block) => block.length < smallest.length ? block : smallest);
}

// Two tiers, because the prototype runs two. A composition of this size settling over the
// same interval as the prompt arriving reads as one slab moving at a single rate.
test("travel and appear are separate Appearance tokens", () => {
    assert.equal(duration(tier("compositionTravel")), 380);
    assert.equal(duration(tier("compositionAppear")), 180);
    assert.equal(duration(tier("compositionAppear"), "riseDuration"), 240);
});

test("the appear tier is quicker than the composition it arrives over", () => {
    const travel = duration(tier("compositionTravel"));

    assert.ok(duration(tier("compositionAppear")) < travel);
    assert.ok(duration(tier("compositionAppear"), "riseDuration") < travel);
});

// M3 emphasized — the curve the whole reveal used to share — puts its first control point at
// y=0, so a travelling element hesitates before it moves. The prototype's curve leaves
// immediately and coasts into place.
test("the travel curve leaves immediately", () => {
    assert.deepEqual(curve(tier("compositionTravel")), [0.2, 0.8, 0.2, 1.0, 1, 1]);
});

// Qt reads bezierCurve as groups of three points and requires the last to be (1, 1). A
// four-number curve is rejected outright, and the easing silently falls back to linear.
test("both tiers spell out a complete cubic bezier", () => {
    for (const name of ["compositionTravel", "compositionAppear"]) {
        const points = curve(tier(name));

        assert.equal(points.length, 6, `${name} is not a complete curve`);
        assert.deepEqual(points.slice(-2), [1, 1], `${name} does not end at (1, 1)`);
    }
});

test("the clock and the profile travel on the travel token", () => {
    for (const element of ["LockClock", "LockProfile"]) {
        const [block] = blocks(surface, element);

        assert.match(block, /Appearance\.animation\.compositionTravel\.duration/);
        assert.match(block, /Appearance\.animation\.compositionTravel\.bezierCurve/);
    }
});

test("no part of the reveal is left on the single slow speed", () => {
    assert.doesNotMatch(surface, /elementMoveSlow/);
    assert.doesNotMatch(profile, /elementMoveSlow/);
});

// The prompt and the chip under it are one thing arriving, which is how the prototype has it
// too: the fingerprint chip lives inside `.auth-area`.
test("the prompt and the fingerprint chip appear as one element", () => {
    const authLayer = enclosingItem(surface, "LockAuthArea {");

    assert.ok(authLayer.includes("LockFingerprint {"));
    // Its own layer rather than the whole composition: the clock and the profile travel
    // while these two fade, and one element cannot do both.
    assert.ok(!authLayer.includes("LockClock"));
});

test("the appearing elements fade and rise together on the appear token", () => {
    const appearing = [enclosingItem(surface, "LockAuthArea {"), blocks(surface, "LockPowerControls")[0]];

    for (const block of appearing) {
        assert.match(block, /opacity: root\.revealed \? 1 : 0/);
        assert.match(block, /Appearance\.animation\.compositionAppear\.duration/);

        // A rise into place rather than a bare fade, as a transform: the y a layout produces
        // must stay the layout's, or a message growing the prompt would animate as a reveal.
        assert.match(block, /transform: Translate/);
        assert.match(block, /Appearance\.sizes\.lockRevealRise/);
        assert.match(block, /Appearance\.animation\.compositionAppear\.riseDuration/);
    }
});

test("the rise distance is a token rather than a literal", () => {
    assert.match(appearance, /readonly property real lockRevealRise: 14\b/);
});

// The surface is constructed at the moment the lock is raised, so construction is the
// entrance and no lifecycle change is needed to drive it.
test("raising the lock animates the content in", () => {
    assert.match(surface, /property real entranceScale: 0\.9\b/);
    assert.match(surface, /property real entranceOpacity: 0\b/);

    const [completed] = blocks(surface, "Component.onCompleted:");
    assert.ok(completed, "nothing starts the entrance");
    assert.match(completed, /entranceScale = 1\b/);
    assert.match(completed, /entranceOpacity = 1\b/);
});

// The surface colour is opaque by construction because colLayer0 carries the user's
// background transparency. Fading or scaling the background with the content would make the
// entrance a window onto the unlocked session for as long as it ran.
test("the entrance animates the content over an untouched background", () => {
    const content = enclosingItem(surface, "opacity: root.entranceOpacity");

    assert.match(content, /scale: root\.entranceScale\b/);
    assert.ok(content.includes("LockClock {"));
    assert.ok(!content.includes("LockBackground"));

    const [background] = blocks(surface, "LockBackground");
    assert.doesNotMatch(background, /entrance|opacity|scale/);
});
