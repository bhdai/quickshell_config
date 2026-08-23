import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";
import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const { consume } = loadQmlJs(
    new URL("../services/SystemSleepParse.js", import.meta.url),
    ["consume"],
);

test("PrepareForSleep false reports a resume", () => {
    let state = consume("signal sender=:1.0 interface=org.freedesktop.login1.Manager; member=PrepareForSleep", false);
    assert.deepEqual(state, { awaitingArgument: true, resumed: false });

    state = consume("   boolean false", state.awaitingArgument);
    assert.deepEqual(state, { awaitingArgument: false, resumed: true });
});

test("PrepareForSleep true is consumed without reporting a resume", () => {
    let state = consume("signal sender=:1.0 interface=org.freedesktop.login1.Manager; member=PrepareForSleep", false);
    state = consume("   boolean true", state.awaitingArgument);

    assert.deepEqual(state, { awaitingArgument: false, resumed: false });
});

test("unrelated output cannot manufacture a resume", () => {
    assert.deepEqual(consume("   boolean false", false), { awaitingArgument: false, resumed: false });
    assert.deepEqual(consume("signal member=NameAcquired", false), { awaitingArgument: false, resumed: false });
});

test("noise between the signal header and argument keeps the parser waiting", () => {
    let state = consume("signal interface=org.freedesktop.login1.Manager; member=PrepareForSleep", false);
    state = consume("some diagnostic line", state.awaitingArgument);

    assert.deepEqual(state, { awaitingArgument: true, resumed: false });
});

test("the sleep service monitors logind and emits only parsed resumes", () => {
    const service = read(repoRoot, "services", "SystemSleep.qml");
    const [monitor] = blocks(service, "Process");

    assert.match(monitor, /"dbus-monitor", "--system"/);
    assert.match(monitor, /interface='org\.freedesktop\.login1\.Manager'/);
    assert.match(monitor, /member='PrepareForSleep'/);
    assert.match(monitor, /stdout: SplitParser/);
    assert.match(service, /if \(event\.resumed\)\s*root\.resumed\(\)/);
});

test("Time re-arms its minute clock when the system resumes", () => {
    const service = read(repoRoot, "services", "Time.qml");
    const [connection] = blocks(service, "Connections");

    assert.match(service, /precision: SystemClock\.Minutes/);
    assert.match(connection, /target: SystemSleep/);
    assert.match(connection, /function onResumed\(\)/);
    assert.match(service, /clock\.enabled = false;\s*clock\.enabled = true;/);
});
