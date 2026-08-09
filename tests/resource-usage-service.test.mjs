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

test("current network rates remain unavailable until a delta reading exists", () => {
    assert.match(service, /property var downloadBytesPerSecond: null/);
    assert.match(service, /property var uploadBytesPerSecond: null/);
    assert.match(service, /property var previousNetworkStats: null/);
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
    for (const id of ["fileMeminfo", "fileStat", "fileNetwork"]) {
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
    assert.match(service, /ResourceUsageParse\.parseNetDev/);
    assert.match(service, /ResourceUsageParse\.calculateNetworkRates/);
    assert.match(service, /return ResourceUsageParse\.formatBytes\(bytes\)/);
    assert.match(service, /return ResourceUsageParse\.formatRate\(bytesPerSecond\)/);
    assert.doesNotMatch(service, /\.match\(/);
});

test("network deltas publish current rates and their aligned history fields", () => {
    const [poll] = blocks(service, "function poll(appendSample: bool): void");
    const calculation = poll.indexOf("ResourceUsageParse.calculateNetworkRates(");
    const baseline = poll.indexOf("root.previousNetworkStats = networkStats");

    assert.notEqual(calculation, -1, "network rates are not calculated");
    assert.notEqual(baseline, -1, "network counters are not rebaselined");
    assert.ok(calculation < baseline, "network counters are replaced before their delta is calculated");
    assert.match(poll, /root\.downloadBytesPerSecond = networkRates\.downloadBytesPerSecond/);
    assert.match(poll, /root\.uploadBytesPerSecond = networkRates\.uploadBytesPerSecond/);
    assert.match(poll, /downloadBytesPerSecond: downloadSample/);
    assert.match(poll, /uploadBytesPerSecond: uploadSample/);
});

test("CPU temperature discovery is one label-based shell invocation in fallback order", () => {
    assert.match(service, /import "cpu_temperature\.js" as CpuTemperature/);

    const [resolver] = blocks(service, "Process");
    assert.match(resolver, /running: true/);
    assert.match(resolver, /command: \["sh", "-c",/);
    assert.match(resolver, /for want in coretemp k10temp acpitz/);
    assert.match(resolver, /for l in .*temp\*_label/);
    assert.match(resolver, /Package id .*\*\|Tdie/);
    assert.match(resolver, /Tctl\) \[ -n .*\$pick.* \] \|\| pick=\$c/);
    assert.doesNotMatch(resolver, /thinkpad/);
});

test("resolved CPU temperature metadata and path are published from the parse library", () => {
    assert.match(service, /property var cpuTemperature: null/);
    assert.match(service, /property var cpuTemperatureCritical: null/);
    assert.match(service, /property string cpuTemperatureChip: ""/);
    assert.match(service, /property string cpuTemperatureLabel: ""/);

    const [accept] = blocks(service, "function acceptCpuTemperatureSensor(stdout: string): void");
    assert.match(accept, /CpuTemperature\.parseSensorLine\(stdout\)/);
    assert.match(accept, /root\.cpuTemperatureChip = sensor\.chip/);
    assert.match(accept, /root\.cpuTemperatureLabel = sensor\.label/);
    assert.match(accept, /root\.cpuTemperatureCritical = sensor\.criticalCelsius/);
    assert.match(accept, /fileCpuTemperature\.path = sensor\.path/);

    const [resolver] = blocks(service, "Process");
    assert.match(resolver, /stdout: StdioCollector/);
    assert.match(resolver, /root\.acceptCpuTemperatureSensor/);

    const temperatureView = blocks(service, "FileView")
        .find(block => block.includes("id: fileCpuTemperature"));
    assert.ok(temperatureView);
    assert.match(temperatureView, /blockAllReads: true/);
    assert.match(temperatureView, /printErrors: false/);
});

test("CPU temperature is read on the aligned poll and gaps history when unavailable", () => {
    const [poll] = blocks(service, "function poll(appendSample: bool): void");
    const reload = poll.indexOf("fileCpuTemperature.reload()");
    const read = poll.indexOf("CpuTemperature.parseTemperature(fileCpuTemperature.text())");

    assert.notEqual(reload, -1, "temperature is not polled");
    assert.ok(reload < read, "temperature is read before its blocking reload");
    assert.match(poll, /let temperatureSample = NaN/);
    assert.match(poll, /root\.cpuTemperature = temperature/);
    assert.match(poll, /temperatureSample = temperature/);
    assert.match(poll, /cpuTemperatureC: temperatureSample/);

    const temperatureView = blocks(service, "FileView")
        .find(block => block.includes("id: fileCpuTemperature"));
    assert.match(temperatureView, /onLoaded: root\.cpuTemperature = CpuTemperature\.parseTemperature\(fileCpuTemperature\.text\(\)\)/);
});

test("a failed temperature path clears the sensor and runs discovery again", () => {
    const [rediscover] = blocks(service, "function rediscoverCpuTemperature(): void");
    const clearPath = rediscover.indexOf('fileCpuTemperature.path = ""');
    const restart = rediscover.indexOf("cpuTemperatureResolver.running = true");

    assert.match(rediscover, /root\.cpuTemperature = null/);
    assert.match(rediscover, /root\.cpuTemperatureCritical = null/);
    assert.match(rediscover, /root\.cpuTemperatureChip = ""/);
    assert.match(rediscover, /root\.cpuTemperatureLabel = ""/);
    assert.ok(clearPath < restart, "discovery restarts before the failed path is cleared");

    const temperatureView = blocks(service, "FileView")
        .find(block => block.includes("id: fileCpuTemperature"));
    assert.match(temperatureView, /onLoadFailed: root\.rediscoverCpuTemperature\(\)/);
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
