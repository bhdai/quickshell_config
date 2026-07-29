import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockDir = path.join(repoRoot, "modules", "lock");
const servicesDir = path.join(repoRoot, "services");

const cluster = read(lockDir, "LockStatusCluster.qml");
const surface = read(lockDir, "LockSurface.qml");

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
    assert.match(gated[0], /Battery\.symbol/);
    assert.match(gated[0], /Battery\.percentage/);
});

test("the battery shows its percentage as well as an icon", () => {
    assert.match(cluster, /Math\.round\(Battery\.percentage \* 100\)/);
});

// Absence is ambiguous for a network: a missing icon and no connection look identical, so
// the icon always renders and NetworkParse's own fallback carries the disconnected case.
test("the network icon is never gated behind a condition", () => {
    const [icon] = blocks(cluster, "CustomIcon");

    assert.match(icon, /source:\s*Network\.symbol/);
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
