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

// The approved prototype's numbers (prototypes/auth-interaction-states at 4168ad1,
// prototype.css:107-117), with its `clamp(120px, 18vw, 300px)` resolved for the 1920-wide
// panel this shell runs on. Frozen here because the shipped clock drifted to a third of it.
test("the clock's type metrics are the prototype's", () => {
    assert.equal(sizeToken("lockClock"), 300);
    assert.equal(sizeToken("lockClockDate"), 28);
    assert.equal(sizeToken("lockClockGap"), 26);
});

test("the clock takes its size, date size and gap from those tokens", () => {
    const [time, date] = blocks(clock, "Text");

    assert.match(time, /font\.pixelSize: Appearance\.sizes\.lockClock\b/);
    assert.match(date, /font\.pixelSize: Appearance\.sizes\.lockClockDate\b/);
    assert.match(clock, /spacing: Appearance\.sizes\.lockClockGap\b/);
});

// At 300px the time is display type, not large body text. Without the negative tracking it
// reads as five separate glyphs rather than one deliberate shape, and without the tight
// leading the date sits away from it however small the gap is set.
test("the time carries the prototype's tracking and leading", () => {
    const [time] = blocks(clock, "Text");

    assert.match(time, /font\.letterSpacing: -0\.09 \* Appearance\.sizes\.lockClock\b/);
    assert.match(time, /lineHeight: 0\.86\b/);
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
