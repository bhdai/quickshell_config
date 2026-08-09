import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";
import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const dashboardDir = path.join(repoRoot, "modules", "dashboard");

const warning = loadQmlJs(path.join(dashboardDir, "warning_state.js"), ["CPU_USAGE", "MEMORY_USAGE", "SWAP_USAGE", "STORAGE_OCCUPANCY", "TEMPERATURE_CRITICAL_FRACTION", "atThreshold", "temperatureWarning"]);

const barResources = read(repoRoot, "modules", "bar", "Resources.qml");
const performanceCard = read(dashboardDir, "PerformanceCard.qml");
const cpuCard = read(dashboardDir, "CpuCard.qml");
const memoryCard = read(dashboardDir, "MemoryCard.qml");
const networkCard = read(dashboardDir, "NetworkCard.qml");
const storageCard = read(dashboardDir, "StorageCard.qml");
const plot = read(dashboardDir, "TimeseriesPlot.qml");
const plotKey = read(dashboardDir, "PlotKey.qml");

// The bar states its thresholds as whole percentages; the destination reads the 0–1 fractions
// the service publishes. Same policy, two units, so this is the comparison that would fail if
// either surface were retuned on its own.
function barThreshold(name) {
    const stated = barResources.match(new RegExp(`property int ${name}: (\\d+)`));
    assert.ok(stated, `the bar no longer states ${name}`);
    return Number(stated[1]) / 100;
}

test("CPU, RAM and swap warn at the thresholds the bar already uses", () => {
    assert.equal(warning.CPU_USAGE, barThreshold("cpuWarningThreshold"));
    assert.equal(warning.MEMORY_USAGE, barThreshold("memoryWarningThreshold"));
    assert.equal(warning.SWAP_USAGE, barThreshold("swapWarningThreshold"));
});

test("root-storage occupancy warns at 90%", () => {
    assert.equal(warning.STORAGE_OCCUPANCY, 0.9);
});

// "At or above", so the threshold itself is inside the warning. A reading that had to exceed
// it would leave the stated number as the one value it never described.
test("a reading at its threshold is already in warning state", () => {
    assert.equal(warning.atThreshold(0.9, warning.CPU_USAGE), true);
    assert.equal(warning.atThreshold(0.95, warning.CPU_USAGE), true);
    assert.equal(warning.atThreshold(1, warning.CPU_USAGE), true);
    assert.equal(warning.atThreshold(0.89, warning.CPU_USAGE), false);
    assert.equal(warning.atThreshold(0, warning.CPU_USAGE), false);
});

// The service publishes null for a reading it has not taken, and NaN for a sample it could
// not measure. Neither is a low reading, but neither is grounds for an alarm either.
test("a reading that does not exist is not a reading in warning state", () => {
    assert.equal(warning.atThreshold(null, warning.STORAGE_OCCUPANCY), false);
    assert.equal(warning.atThreshold(undefined, warning.STORAGE_OCCUPANCY), false);
    assert.equal(warning.atThreshold(NaN, warning.STORAGE_OCCUPANCY), false);
    assert.equal(warning.atThreshold("0.95", warning.STORAGE_OCCUPANCY), false);
});

test("temperature warns at 90% of the machine's own critical value", () => {
    assert.equal(warning.TEMPERATURE_CRITICAL_FRACTION, 0.9);
    assert.equal(warning.temperatureWarning(90, 100), true);
    assert.equal(warning.temperatureWarning(105, 100), true);
    assert.equal(warning.temperatureWarning(89, 100), false);
    assert.equal(warning.temperatureWarning(94, 105), false);
});

// A machine that reports no limit has not reported a low one, and 90% of a guessed limit is a
// guess twice over.
test("a machine with no critical value can never enter temperature warning state", () => {
    assert.equal(warning.temperatureWarning(200, null), false);
    assert.equal(warning.temperatureWarning(200, undefined), false);
    assert.equal(warning.temperatureWarning(200, NaN), false);
    // A sensor reporting 0°C as its limit would otherwise put every temperature above it.
    assert.equal(warning.temperatureWarning(40, 0), false);
    assert.equal(warning.temperatureWarning(null, 100), false);
});

// No debounce and no hysteresis means the answer depends on the reading in hand and on
// nothing that came before it — including a reading that was in warning state a moment ago.
test("a recovered reading is out of warning state on the reading that recovered it", () => {
    assert.equal(warning.atThreshold(0.99, warning.CPU_USAGE), true);
    assert.equal(warning.atThreshold(0.5, warning.CPU_USAGE), false);
    assert.equal(warning.temperatureWarning(99, 100), true);
    assert.equal(warning.temperatureWarning(50, 100), false);
});

test("each card names the readings that can warn against the shared thresholds", () => {
    assert.match(cpuCard, /readonly property bool usageWarning: Warning\.atThreshold\(ResourceUsage\.cpuUsage, Warning\.CPU_USAGE\)/);
    assert.match(cpuCard, /readonly property bool temperatureWarning: Warning\.temperatureWarning\(ResourceUsage\.cpuTemperature, ResourceUsage\.cpuTemperatureCritical\)/);
    assert.match(memoryCard, /readonly property bool memoryWarning: Warning\.atThreshold\(ResourceUsage\.memoryUsedPercentage, Warning\.MEMORY_USAGE\)/);
    assert.match(memoryCard, /readonly property bool swapWarning: Warning\.atThreshold\(ResourceUsage\.swapUsedPercentage, Warning\.SWAP_USAGE\)/);
    assert.match(storageCard, /readonly property bool occupancyWarning: Warning\.atThreshold\(ResourceUsage\.diskUsedPercentage, Warning\.STORAGE_OCCUPANCY\)/);
});

// One card, several readings, one of which is the problem. A high CPU that reddened the
// temperature beside it would send the reader to the fan rather than to whatever is running.
test("a reading in warning state recolours itself and no other reading on its card", () => {
    const [usage] = blocks(cpuCard, "Text").filter(text => text.includes("ResourceUsage.cpuUsage"));
    assert.match(usage, /color: root\.usageWarning \? Appearance\.colors\.colError : Appearance\.colors\.colOnLayer2/);

    const [temperature] = blocks(cpuCard, "Text").filter(text => text.includes("root.temperatureText"));
    assert.match(temperature, /color: root\.temperatureWarning \? Appearance\.colors\.colError : Appearance\.colors\.colOnLayer2/);

    const [ram] = blocks(memoryCard, "Text").filter(text => text.includes("ResourceUsage.memoryUsedPercentage"));
    assert.match(ram, /color: root\.memoryWarning \? Appearance\.colors\.colError : Appearance\.colors\.colOnLayer2/);

    const [swap] = blocks(memoryCard, "Text").filter(text => text.includes("ResourceUsage.swapUsedString"));
    assert.match(swap, /color: root\.swapWarning \? Appearance\.colors\.colError : Appearance\.colors\.colOnLayer2/);
});

// Everything that is not the reading keeps the colour it has when the machine is idle: the
// unit beside a figure, the capacity behind it, the threshold under the temperature.
test("units, labels and capacities stay in their ordinary subtext colour", () => {
    for (const card of [cpuCard, memoryCard, storageCard]) {
        for (const text of blocks(card, "Text").filter(text => text.includes("Appearance.colors.colSubtext")))
            assert.doesNotMatch(text, /colError/);
    }
});

// Both are the same number: an arc at 94% of its sweep beside a red 94% would read as two
// different claims about one filesystem.
test("storage recolours the percentage and the arc that draws it, and nothing else", () => {
    const [percentage] = blocks(storageCard, "Text").filter(text => text.includes("root.shownOccupancy"));
    assert.match(percentage, /color: root\.occupancyWarning \? Appearance\.colors\.colError : Appearance\.colors\.colOnLayer2/);

    const [track, active] = blocks(storageCard, "ShapePath");
    assert.match(track, /strokeColor: Appearance\.colors\.colSecondaryContainer/);
    assert.match(active, /strokeColor: root\.occupancyWarning \? Appearance\.colors\.colError : Appearance\.colors\.colSecondary/);

    // The dot marks where a full filesystem would end, which is a fact about the gauge rather
    // than a reading taken off it.
    const [stop] = blocks(storageCard, "Rectangle");
    assert.match(stop, /color: Appearance\.colors\.colSecondary\b/);
});

// The occupancy sweeps up to its reading on every arrival at the destination. Reading the
// warning off that animated value would flash the card through amber on the way to a figure
// it had already been given.
test("storage warns on the reading rather than on the arc's arrival at it", () => {
    assert.match(storageCard, /property bool occupancyWarning: Warning\.atThreshold\(ResourceUsage\.diskUsedPercentage/);
});

// Not deferred — decided never. Nothing here measures a link's capacity, so there is no
// denominator a warning could be a fraction of.
test("network throughput has no warning state at all", () => {
    assert.doesNotMatch(networkCard, /colError/);
    assert.doesNotMatch(networkCard, /warning_state\.js/);
});

// One hot reading is not a hot machine. A card that went red as a whole would say the same
// thing whichever of its four numbers had moved.
test("no whole card, title or symbol is ever recoloured", () => {
    assert.doesNotMatch(performanceCard, /colError/);
    for (const card of [cpuCard, memoryCard, storageCard]) {
        assert.doesNotMatch(card, /color: root\.\w*[Ww]arning \? Appearance\.colors\.colError : Appearance\.colors\.colLayer1/);
        assert.doesNotMatch(card, /radius: .*colError/);
    }
});

// A spike that has passed is not a machine that is still under pressure, and a key that
// changed colour would stop identifying the line it names.
test("history and plot keys keep their identity colours", () => {
    assert.doesNotMatch(plot, /colError/);
    assert.doesNotMatch(plotKey, /colError/);
});

// A reading arrives once a second; the colour is well settled before the next one lands. An
// instant swap would read as a glitch rather than as the machine crossing a line.
test("a reading crosses into warning state on the expressive colour curve", () => {
    for (const [card, property] of [[cpuCard, "color"], [memoryCard, "color"], [storageCard, "strokeColor"]]) {
        const behaviors = blocks(card, `Behavior on ${property}`);
        assert.ok(behaviors.length > 0, `no ${property} transition`);
        for (const behavior of behaviors) {
            assert.match(behavior, /ColorAnimation/);
            assert.match(behavior, /duration: Appearance\.animation\.elementMove\.duration/);
            assert.match(behavior, /easing\.bezierCurve: Appearance\.animation\.expressiveEffects/);
        }
    }
});
