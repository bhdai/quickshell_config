import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockDir = path.join(repoRoot, "modules", "lock");
const servicesDir = path.join(repoRoot, "services");

const cluster = read(lockDir, "LockStatusCluster.qml");
const surface = read(lockDir, "LockSurface.qml");
const statusIcons = read(repoRoot, "modules", "bar", "StatusIcons.qml");

function withoutComments(source) {
    return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
}

test("the cluster is instantiated exactly once in the surface", () => {
    assert.equal(blocks(surface, "LockStatusCluster").length, 1);
});

// Absence is meaningful for a battery: on a machine with no laptop battery there is nothing
// to say, and an empty slot is honest.
test("the battery renders only when a laptop battery is present", () => {
    const gated = blocks(cluster, "Loader").filter(block => /active:\s*Battery\.available/.test(block));

    assert.equal(gated.length, 1);
    assert.match(gated[0], /Battery\.percentage/);
});

// The bar's battery, from the widget the bar composes it from — not a second drawing of the
// same thing, and not BatteryIndicator itself, whose MouseArea would be a dead zone on a
// surface where a click anywhere is what opens the password prompt.
test("the battery is the shared bar widget rather than a lock-owned copy", () => {
    const [battery] = blocks(cluster, "ClippedProgressBar");

    assert.ok(battery, "the battery is not drawn with ClippedProgressBar");
    assert.match(battery, /value:\s*Battery\.percentage/);
    assert.match(battery, /text:\s*Math\.round\(Battery\.percentage \* 100\)/);

    assert.doesNotMatch(withoutComments(cluster), /BatteryIndicator|MouseArea\s*\{/);
});

// The bar leaves the body size, the nob and the text style at the widget's defaults. Setting
// any of them here is the lock screen drifting away from the bar rather than matching it.
test("the battery body is left at the size the bar leaves it", () => {
    const [battery] = blocks(cluster, "ClippedProgressBar");

    assert.doesNotMatch(battery, /valueBarWidth:|valueBarHeight:|font:|radius:/);
});

// "The same as in the bar" has to be one number, not two that happen to agree today.
test("both status clusters size their icons from one token", () => {
    assert.match(cluster, /iconSize:\s*Appearance\.sizes\.statusIcon/);
    assert.match(statusIcons, /iconSize:\s*Appearance\.sizes\.statusIcon/);
});

// Absence is ambiguous for a network: a missing icon and no connection look identical, so
// the icon always renders and NetworkParse's own fallback carries the disconnected case.
test("the network icon is never gated behind a condition", () => {
    const [icon] = blocks(cluster, "CustomIcon").filter(block => /Network\.symbol/.test(block));

    assert.ok(icon, "the network icon is not a CustomIcon");
    assert.doesNotMatch(icon, /^\s*(visible|active|enabled):/m);

    const gatedLoaders = blocks(cluster, "Loader").filter(block => /Network\./.test(block));
    assert.deepEqual(gatedLoaders, []);
});

test("the network symbol comes from the existing selection rather than a second copy", () => {
    for (const name of ["LockStatusCluster.qml", "LockSurface.qml"]) {
        const code = withoutComments(read(lockDir, name));
        assert.doesNotMatch(code, /pickNetworkSymbol|network-wireless|network-wired/, `${name} reimplements the symbol choice`);
    }
});

// The icon answers "am I online", which is what matters while locked. The name only tells a
// passer-by which network the machine is on.
test("no network name reaches the lock surface", () => {
    const code = withoutComments(cluster);

    assert.doesNotMatch(code, /networkName|ssid|Ssid|SSID/);
});

test("the keyboard layout is seeded on the compositor-confirmed lock", () => {
    assert.match(cluster, /Lock\.secure/);
    assert.match(cluster, /KeyboardLayout\.refresh\(\)/);
});

// The repo already ships this glyph, and drawing it the same way as the network icon keeps
// the two halves of the cluster one system rather than one icon set beside another.
test("the keyboard icon is the shipped asset, drawn like the network icon", () => {
    const [icon] = blocks(cluster, "CustomIcon").filter(block => /input-keyboard-symbolic/.test(block));

    assert.ok(icon, "the keyboard icon is not the shipped input-keyboard-symbolic asset");
    assert.match(icon, /colorize: true/);
});

test("the layout indicator reads the service rather than running its own query", () => {
    const code = withoutComments(cluster);

    assert.match(code, /KeyboardLayout\.layout/);
    assert.doesNotMatch(code, /Process\s*\{|hyprctl/);
});

// #50 rejected a subprocess repeating for the whole lock duration. A one-shot read on an
// edge is not that; a timer anywhere in this path would be.
test("nothing in the lock module or the layout service polls", () => {
    const sources = [
        ["LockStatusCluster.qml", cluster],
        ["LockSurface.qml", surface],
        ["KeyboardLayout.qml", read(servicesDir, "KeyboardLayout.qml")],
    ];

    for (const [name, source] of sources)
        assert.doesNotMatch(withoutComments(source), /Timer\s*\{|Component\.onCompleted:\s*running\s*=/, `${name} polls`);
});

test("the layout query runs only when it is asked to", () => {
    const [process] = blocks(read(servicesDir, "KeyboardLayout.qml"), "Process");

    assert.doesNotMatch(withoutComments(process), /^\s*running:\s*true/m);
});

// The non-negotiable of #67: a dead UPower must never gate PAM. Neither the lock host nor
// the singleton that owns the state machine may name a status service, so there is no
// property on the unlock path that could be waiting on one.
test("nothing on the lock path names a status service", () => {
    const onPath = [
        ["LockModule.qml", read(lockDir, "LockModule.qml")],
        ["Lock.qml", read(servicesDir, "Lock.qml")],
    ];

    for (const [name, source] of onPath)
        assert.doesNotMatch(withoutComments(source), /\b(Battery|Network|KeyboardLayout)\b/, `${name} depends on a status service`);
});
