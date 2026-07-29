import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockDir = path.join(repoRoot, "modules", "lock");

function lockQml(name) {
    return read(lockDir, name);
}

function lockQmlFiles() {
    return readdirSync(lockDir).filter(name => name.endsWith(".qml"));
}

// The guarantee is structural: the surface's own colour is an opaque themed backstop and
// every image draws on top of it, so a missing, renamed or still-decoding wallpaper
// degrades to a themed solid surface and no code path yields a transparent lock.
test("the lock surface paints an opaque themed colour of its own", () => {
    assert.match(lockQml("LockSurface.qml"), /^\s*color: Appearance\.m3colors\.m3background$/m);
});

test("the wallpaper is drawn on top of that colour, never as the surface colour", () => {
    const background = lockQml("LockBackground.qml");
    assert.equal(blocks(background, "Image").length, 1);
    assert.doesNotMatch(background, /^\s*color: .*(source|wallpaper)/im);
});

// A 4 MB photo decoded synchronously at full resolution would hold the lock off the
// screen for as long as the decode takes.
test("the wallpaper decodes asynchronously at screen size", () => {
    const [image] = blocks(lockQml("LockBackground.qml"), "Image");
    assert.match(image, /asynchronous: true/);
    assert.match(image, /sourceSize\.width:/);
    assert.match(image, /sourceSize\.height:/);
});

test("the wallpaper comes from one swappable property, with no discovery or config parsing", () => {
    const declarations = lockQmlFiles()
        .flatMap(name => lockQml(name).split("\n").map(line => ({ name, line })))
        .filter(({ line }) => /property\s+url\s+source/.test(line));

    assert.deepEqual(declarations.map(({ name }) => name), ["LockBackground.qml"]);

    // Comments stripped: naming hyprpaper as the thing kept in sync by hand is the point,
    // reading its config to find out is what must not happen.
    for (const name of lockQmlFiles()) {
        const code = lockQml(name).replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
        assert.doesNotMatch(code, /Process\s*\{|FileView\s*\{|\.conf/, `${name} discovers the wallpaper`);
    }
});

// One element that travels. Two copies cross-faded would read as a swap, and would also
// mean two avatars loading the same file.
test("exactly one profile element exists in the surface", () => {
    const instantiations = lockQmlFiles()
        .filter(name => name !== "LockProfile.qml")
        .flatMap(name => blocks(lockQml(name), "LockProfile"));

    assert.equal(instantiations.length, 1);
});

test("the avatar falls back to a themed symbol rather than a broken image", () => {
    const profile = lockQml("LockProfile.qml");
    assert.match(profile, /Image\.Ready/);
    assert.match(profile, /"person"/);
});

// Reveal and dismiss are the same animation played in both directions, which is what
// makes them the same pace by construction rather than by two matching literals.
test("every animation in the lock module is timed from an Appearance token", () => {
    const offenders = [];

    for (const name of lockQmlFiles()) {
        lockQml(name).split("\n").forEach((line, index) => {
            const duration = line.match(/duration:\s*(.+)/);
            if (duration && !duration[1].includes("Appearance.animation"))
                offenders.push(`${name}:${index + 1}`);
        });
    }

    assert.deepEqual(offenders, []);
});

// The prompt is where an unlock would be worth smuggling in, so it is the one component with
// no way to reach the lock at all: it is handed what to show and reports what the user did.
// That is also what lets a test drive all six states with no PAM behind it.
test("the password prompt reads no singleton", () => {
    // Comments stripped: the file says what it does not reach, and saying so is not reaching.
    const prompt = lockQml("LockAuthArea.qml").replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");

    assert.doesNotMatch(prompt, /^import qs\.services$/m);
    assert.doesNotMatch(prompt, /\bLock\./);
});

test("the surface hardcodes no colour", () => {
    const offenders = [];

    for (const name of lockQmlFiles()) {
        lockQml(name).split("\n").forEach((line, index) => {
            if (/"#[0-9a-fA-F]{3,8}"/.test(line))
                offenders.push(`${name}:${index + 1}`);
        });
    }

    assert.deepEqual(offenders, []);
});
