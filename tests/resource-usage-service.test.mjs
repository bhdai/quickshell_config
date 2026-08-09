import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const service = read(repoRoot, "services", "ResourceUsage.qml");
const barResources = read(repoRoot, "modules", "bar", "Resources.qml");

test("history is a read-only 60-row model contract with one update signal", () => {
    assert.match(service, /readonly property alias history: historyModel/);
    assert.match(service, /readonly property int historyCapacity: 60/);
    assert.match(service, /signal historyUpdated\(\)/);
    assert.match(service, /ListModel\s*\{\s*id: historyModel\s*\}/);
});

test("rolling history publishes one coherent aligned sample before notifying", () => {
    const [append] = blocks(service, "function appendHistory(sample: var): void");

    assert.match(append, /if \(historyModel\.count >= root\.historyCapacity\)\s*historyModel\.remove\(0\);/);
    for (const role of [
        "cpuUsage",
        "cpuTemperatureC",
        "memoryUsedPercentage",
        "swapUsedPercentage",
        "downloadBytesPerSecond",
        "uploadBytesPerSecond",
    ])
        assert.match(append, new RegExp(`${role}:`), `history omits ${role}`);

    const modelAppend = append.indexOf("historyModel.append(");
    const notification = append.indexOf("root.historyUpdated()");
    assert.ok(modelAppend < notification, "history notifies before the row is coherent");
    assert.equal(append.match(/root\.historyUpdated\(\)/g)?.length, 1);
});

test("sampling starts immediately and then runs continuously once per second", () => {
    const [timer] = blocks(service, "Timer");

    assert.match(service, /Component\.onCompleted: root\.poll\(false\)/);
    assert.match(timer, /interval: 1000/);
    assert.match(timer, /running: true/);
    assert.match(timer, /repeat: true/);
    assert.match(timer, /onTriggered: root\.poll\(true\)/);
    assert.doesNotMatch(service, /updateInterval/);
});

test("polled proc files use blocking reload-then-read I/O", () => {
    for (const file of blocks(service, "FileView"))
        assert.match(file, /blockAllReads: true/);

    const [poll] = blocks(service, "function poll(appendSample: bool): void");
    for (const id of ["fileMeminfo", "fileStat"]) {
        const reload = poll.indexOf(`${id}.reload()`);
        const read = poll.indexOf(`${id}.text()`);
        assert.notEqual(reload, -1, `${id} is not reloaded`);
        assert.ok(reload < read, `${id} is read before its blocking reload`);
    }
});

test("the QML service delegates parsing and formatting to its pure library", () => {
    assert.match(service, /import "ResourceUsageParse\.js" as ResourceUsageParse/);
    assert.match(service, /ResourceUsageParse\.parseMeminfo/);
    assert.match(service, /ResourceUsageParse\.parseCpuStat/);
    assert.match(service, /ResourceUsageParse\.calculateCpuUsage/);
    assert.match(service, /return ResourceUsageParse\.formatBytes\(bytes\)/);
    assert.match(service, /return ResourceUsageParse\.formatRate\(bytesPerSecond\)/);
    assert.doesNotMatch(service, /\.match\(/);
});

test("clearing history emits exactly once after the model is empty", () => {
    const [clear] = blocks(service, "function clearHistory(): void");
    const modelClear = clear.indexOf("historyModel.clear()");
    const notification = clear.indexOf("root.historyUpdated()");

    assert.ok(modelClear < notification, "history notifies before it is cleared");
    assert.equal(clear.match(/root\.historyUpdated\(\)/g)?.length, 1);
});

test("a timing discontinuity clears, rebaselines, and skips that row", () => {
    const [poll] = blocks(service, "function poll(appendSample: bool): void");
    const baseline = poll.indexOf("root.previousCpuStats = cpuStats");
    const discontinuity = poll.indexOf("if (discontinuity)");
    const clear = poll.indexOf("root.clearHistory()", discontinuity);
    const skipped = poll.indexOf("return;", clear);
    const append = poll.indexOf("root.appendHistory(");

    assert.ok(baseline < discontinuity, "CPU is not rebaselined before discontinuity handling");
    assert.ok(discontinuity < clear && clear < skipped && skipped < append,
        "the discontinuity row can reach history");
});

test("parse failures leave current scalars standing and only gap their sample", () => {
    const [poll] = blocks(service, "function poll(appendSample: bool): void");
    const [memorySuccess] = blocks(poll, "if (memory)");
    const [cpuSuccess] = blocks(poll, "if (usage !== null)");

    for (const property of ["memoryTotal", "memoryFree", "swapTotal", "swapFree"])
        assert.match(memorySuccess, new RegExp(`root\\.${property} =`));
    assert.match(cpuSuccess, /root\.cpuUsage = usage/);
    assert.match(poll, /let memorySample = NaN/);
    assert.match(poll, /let swapSample = NaN/);
    assert.match(poll, /let cpuSample = NaN/);
});

test("the bar keeps its existing scalar bindings", () => {
    assert.match(barResources, /percentage: ResourceUsage\.memoryUsedPercentage/);
    assert.match(barResources, /percentage: ResourceUsage\.swapUsedPercentage/);
    assert.match(barResources, /visible: ResourceUsage\.swapTotal > 1/);
    assert.match(barResources, /percentage: ResourceUsage\.cpuUsage/);
});
