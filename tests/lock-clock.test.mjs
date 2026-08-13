import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockDir = path.join(repoRoot, "modules", "lock");
const appearance = read(repoRoot, "modules", "common", "Appearance.qml");
const clock = read(lockDir, "LockClock.qml");

function sizeToken(name) {
    const declaration = appearance.match(new RegExp(`readonly property real ${name}: ([\\d.]+)`));
    assert.ok(declaration, `Appearance.sizes.${name} is not declared`);
    return Number(declaration[1]);
}

// The date's bounds are still the approved prototype's (prototypes/auth-interaction-states
// at 4168ad1, prototype.css:107-117). The time's ceiling and the gap were tuned down from
// it on hardware: the prototype's 300px took about a quarter of a 1200px-tall panel's
// height in one word.
test("the clock's type metrics are the tuned display sizes", () => {
    assert.equal(sizeToken("lockClockMin"), 120);
    assert.equal(sizeToken("lockClockMax"), 240);
    assert.equal(sizeToken("lockClockDateMin"), 18);
    assert.equal(sizeToken("lockClockDateMax"), 28);
    assert.equal(sizeToken("lockClockGap"), 21);
});

// A flat size is a size tuned on one panel. What sits between the bounds is a fraction of
// the width of the output the clock is composed on, set just under where the ceiling would
// take over on a 1920 output so the clamp still behaves as a clamp rather than collapsing
// to a constant on every display this runs on.
test("the clock is sized from the output between those bounds", () => {
    assert.match(clock, /property real availableWidth/);
    assert.match(clock, /readonly property real timeFraction: 0\.145\b/);
    assert.match(clock, /readonly property real dateFraction: 0\.016\b/);
    assert.match(clock, /timeSize: Math\.max\(Appearance\.sizes\.lockClockMin, Math\.min\(root\.availableWidth \* root\.timeFraction, Appearance\.sizes\.lockClockMax\)\)/);
    assert.match(clock, /dateSize: Math\.max\(Appearance\.sizes\.lockClockDateMin, Math\.min\(root\.availableWidth \* root\.dateFraction, Appearance\.sizes\.lockClockDateMax\)\)/);
});

test("the clock takes its size, date size and gap from those", () => {
    const [time, date] = blocks(clock, "Text");

    assert.match(time, /font\.pixelSize: root\.timeSize\b/);
    assert.match(date, /font\.pixelSize: root\.dateSize\b/);
    assert.match(clock, /spacing: Appearance\.sizes\.lockClockGap\b/);
});

// The surface is the only thing that knows how wide the output is, and a clock left at the
// default width would fall to the lower bound on every screen.
test("the surface hands the clock the width it is composed on", () => {
    const [instantiation] = blocks(read(lockDir, "LockSurface.qml"), "LockClock");

    assert.match(instantiation, /availableWidth: parent\.width\b/);
});

// At 240px the time is display type, not large body text. Without the negative tracking it
// reads as five separate glyphs rather than one deliberate shape, and without the tight
// leading the date sits away from it however small the gap is set.
//
// The coefficient is tuned against the weight, so the two are asserted together: thin
// strokes need pulling together harder, and carrying a Light face's tracking under a
// heavier one closes the counters.
test("the time carries its tracking and leading", () => {
    const [time] = blocks(clock, "Text");

    assert.match(time, /font\.weight: Font\.Normal\b/);
    assert.match(time, /font\.letterSpacing: -0\.07 \* root\.timeSize\b/);
    assert.match(time, /lineHeight: 0\.86\b/);
});

// A distance field is cached at one base size and scaled to whatever the text asks for,
// which at display size — and again through the reveal's `scale` — reads as a blown-up
// bitmap rather than as type.
test("the time is drawn from curves rather than from a scaled distance field", () => {
    const [time] = blocks(clock, "Text");

    assert.match(time, /renderType: Text\.CurveRendering\b/);
});

// "hh:mm" holds its character count, but a proportional font gives each digit its own
// advance, so the width of the string — and with it a centred clock — moves every minute.
test("the digits are tabular, so the centred clock holds still", () => {
    const [time] = blocks(clock, "Text");

    assert.match(time, /font\.features: \(\{[\s\S]*"tnum": 1/);
});

test("no lock file sets a font size or a spacing as a literal", () => {
    const offenders = [];

    for (const name of readdirSync(lockDir).filter(entry => entry.endsWith(".qml"))) {
        read(lockDir, name).split("\n").forEach((line, index) => {
            if (/(?:font\.pixelSize|spacing):\s*[\d.]+\s*$/.test(line))
                offenders.push(`${name}:${index + 1}`);
        });
    }

    assert.deepEqual(offenders, []);
});
