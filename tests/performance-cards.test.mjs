import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const dashboardDir = path.join(repoRoot, "modules", "dashboard");

const pane = read(dashboardDir, "PerformancePane.qml");
const card = read(dashboardDir, "PerformanceCard.qml");
const cpuCard = read(dashboardDir, "CpuCard.qml");
const memoryCard = read(dashboardDir, "MemoryCard.qml");
const plot = read(dashboardDir, "TimeseriesPlot.qml");

// The pane is a fixed canvas divided between cards, so where a card sits is a fact about
// the destination rather than about the card. Written inline, four cards' worth of these
// numbers could no longer be shown to add up to the pane.
test("a card is placed at the rectangle the metrics module names for it", () => {
    for (const [type, name] of [["CpuCard", "cpu"], ["MemoryCard", "memory"]]) {
        const [placement] = blocks(pane, type);

        assert.match(placement, new RegExp(`x: Metrics\\.PERFORMANCE_CARD\\.${name}\\.x`));
        assert.match(placement, new RegExp(`y: Metrics\\.PERFORMANCE_CARD\\.${name}\\.y`));
        assert.match(placement, new RegExp(`width: Metrics\\.PERFORMANCE_CARD\\.${name}\\.width`));
        assert.match(placement, new RegExp(`height: Metrics\\.PERFORMANCE_CARD\\.${name}\\.height`));
    }
});

test("the inner card is the dashboard's existing grammar", () => {
    assert.match(card, /color: Appearance\.colors\.colLayer1/);
    assert.match(card, /radius: Appearance\.rounding\.small/);
    assert.match(card, /anchors\.margins: Metrics\.PERFORMANCE_CARD_PAD/);

    const [symbol] = blocks(card, "MaterialSymbol");
    assert.match(symbol, /iconSize: 24/);
    assert.match(symbol, /fill: 1/);

    const [title] = blocks(card, "Text");
    assert.match(title, /font\.weight: Font\.DemiBold/);
});

test("the CPU card leads with the current aggregate usage", () => {
    assert.match(cpuCard, /symbol: "developer_board"/);
    assert.match(cpuCard, /text: Math\.round\(ResourceUsage\.cpuUsage \* 100\)/);
});

// A card that reported 0°C on a machine with no readable sensor would be indistinguishable
// from a cold one, and a threshold it cannot read is not one it may state.
test("an unavailable temperature is an em dash with no threshold beside it", () => {
    assert.match(cpuCard, /temperatureAvailable: ResourceUsage\.cpuTemperature !== null/);
    assert.match(cpuCard, /temperatureText: root\.temperatureAvailable \? `\$\{ResourceUsage\.cpuTemperature\}°C` : "—"/);
    assert.match(cpuCard, /criticalText: root\.temperatureAvailable && ResourceUsage\.cpuTemperatureCritical !== null \?/);

    const [criticalLine] = blocks(cpuCard, "Text").filter(text => text.includes("root.criticalText"));
    assert.match(criticalLine, /visible: root\.criticalText !== ""/);
});

// Degrees and percent share no scale. A second line for temperature would make the plot's
// vertical axis mean whichever of the two the reader guessed at.
test("temperature is a reading beside the plot rather than a series on it", () => {
    const [series] = blocks(cpuCard, "TimeseriesPlot");

    assert.match(series, /primaryRole: "cpuUsage"/);
    assert.doesNotMatch(series, /secondaryRole/);
    assert.doesNotMatch(series, /cpuTemperature/);
    // The ceiling is the machine fully busy, and it never moves.
    assert.match(series, /maximum: 1\b/);
    assert.doesNotMatch(series, /ceilingLabel/);
});

// A percentage on a machine the reader does not know the size of says how full it is without
// saying how much that is.
test("the memory card leads with the RAM percentage against the capacity behind it", () => {
    assert.match(memoryCard, /symbol: "memory"/);
    assert.match(memoryCard, /text: Math\.round\(ResourceUsage\.memoryUsedPercentage \* 100\)/);
    assert.match(memoryCard, /ResourceUsage\.memoryUsedString.*ResourceUsage\.memoryTotalString/);
});

// The machine reaching past RAM is one movement. Swap on a card of its own would put the
// cause and the consequence side by side and leave the reader to line up their timelines.
test("swap is a second reading on the memory card", () => {
    assert.match(memoryCard, /ResourceUsage\.swapUsedString.*ResourceUsage\.swapTotalString/);

    const [series] = blocks(memoryCard, "TimeseriesPlot");
    assert.match(series, /primaryRole: "memoryUsedPercentage"/);
    assert.match(series, /secondaryRole: root\.swapConfigured \? "swapUsedPercentage" : ""/);
});

// Zero of a resource that does not exist is a reading about nothing, and a machine without
// swap is not a degraded version of one that has it.
test("with no swap configured its reading and its series are both omitted", () => {
    assert.match(memoryCard, /readonly property bool swapConfigured: ResourceUsage\.swapTotal > 0/);

    const [reading] = blocks(memoryCard, "Column");
    assert.match(reading, /visible: root\.swapConfigured/);

    const [series] = blocks(memoryCard, "TimeseriesPlot");
    assert.match(series, /secondaryKey: root\.swapConfigured \? "Swap" : ""/);

    // The plot fills whatever series is left alone on the scale, and the card's rectangle is
    // the pane's to name — so neither presentation follows from whether swap is there.
    assert.match(plot, /readonly property bool filled: root\.secondaryRole === ""/);
    assert.doesNotMatch(memoryCard, /^\s*(width|height|implicitWidth|implicitHeight):/m);
});

// Two metrics on one plot only mean anything against each other if they are on one scale, and
// a line is only identifiable if its key carries its own colour.
test("RAM and swap share a fixed full-scale plot and their colours", () => {
    const [series] = blocks(memoryCard, "TimeseriesPlot");

    assert.match(series, /maximum: 1\b/);
    assert.doesNotMatch(series, /ceilingLabel/);
    assert.match(series, /primaryColor: Appearance\.colors\.colPrimary/);
    assert.match(series, /secondaryColor: Appearance\.colors\.colTertiary/);
    assert.match(series, /primaryKey: "RAM"/);
});

// The ring rolls at capacity, so its count stops changing while its contents do not. Nothing
// else the plot can watch says a sample has arrived.
test("the plot rebuilds on a new sample and not on a clock", () => {
    const [connections] = blocks(plot, "Connections");

    assert.match(connections, /target: ResourceUsage/);
    assert.match(connections, /function onHistoryUpdated\(\): void \{\s*root\.rebuild\(\);/);
    assert.doesNotMatch(plot, /Timer\s*\{|FrameAnimation|NumberAnimation/);
});

test("the plot draws nothing until there are two samples to draw a line between", () => {
    assert.match(plot, /readonly property bool collecting: ResourceUsage\.history\.count < Plot\.MIN_SAMPLES/);

    const [message] = blocks(plot, "Text").filter(text => text.includes("Collecting"));
    assert.match(message, /text: "Collecting 60-second history…"/);
    assert.match(message, /visible: root\.collecting/);

    const [shape] = blocks(plot, "Shape");
    assert.match(shape, /visible: !root\.collecting/);
});

// The scale arrives from the caller. A renderer that inferred its own would rescale under
// the reader, leaving a rise in the line to mean either more of the metric or less headroom.
test("the plot never infers its own vertical scale", () => {
    assert.match(plot, /property real maximum: 1/);
    assert.doesNotMatch(plot, /Math\.max\(\.\.\./);

    const [rebuild] = blocks(plot, "function rebuild(): void");
    assert.match(rebuild, /Plot\.seriesSegments\(root\.readSeries\(root\.primaryRole\), root\.maximum,/);
});

// Two filled series would each hide the other where they cross, and a line drawn over a
// second series' fill is a different colour from the same line drawn over the card.
test("the area fill belongs to a plot with one series on it", () => {
    assert.match(plot, /readonly property bool filled: root\.secondaryRole === ""/);

    const [rebuild] = blocks(plot, "function rebuild(): void");
    assert.match(rebuild, /root\.primaryAreas = root\.filled \?/);
});

// A key that named its series in the card's foreground colour would need a legend of its
// own to say which line it meant.
test("the plot states the window it covers and names its lines in their own colours", () => {
    assert.match(plot, /text: "Last 60 seconds"/);

    const keys = blocks(plot, "PlotKey");
    assert.deepEqual(keys.map(key => /color: (root\.\w+)/.exec(key)[1]), ["root.primaryColor", "root.secondaryColor"]);
});
