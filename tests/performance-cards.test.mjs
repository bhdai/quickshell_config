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
const networkCard = read(dashboardDir, "NetworkCard.qml");
const plot = read(dashboardDir, "TimeseriesPlot.qml");

// The pane is a fixed canvas divided between cards, so where a card sits is a fact about
// the destination rather than about the card. Written inline, four cards' worth of these
// numbers could no longer be shown to add up to the pane.
test("a card is placed at the rectangle the metrics module names for it", () => {
    for (const [type, name] of [["CpuCard", "cpu"], ["MemoryCard", "memory"], ["NetworkCard", "network"]]) {
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

// Neither direction is the one the other is read against: a download buried under an upload
// or beside it in smaller type would make the card an answer to only one of the two questions
// a reader opens it with.
test("both directions are the network card's headline", () => {
    assert.match(networkCard, /symbol: "network_check"/);

    // One line each, from the same three components, so the two directions cannot drift into
    // different weights: what differs between them is the direction, its colour and its
    // readings. The grid is what lines their columns up without a width written anywhere.
    const [headline] = blocks(networkCard, "Grid");
    assert.match(headline, /columns: 3/);

    const [downArrow, upArrow] = blocks(networkCard, "DirectionArrow");
    assert.match(downArrow, /text: "arrow_downward"/);
    assert.match(downArrow, /color: Appearance\.colors\.colPrimary/);
    assert.match(upArrow, /text: "arrow_upward"/);
    assert.match(upArrow, /color: Appearance\.colors\.colTertiary/);

    const [download, upload] = blocks(networkCard, "CurrentRate");
    assert.match(download, /text: ResourceUsage\.formatRate\(ResourceUsage\.downloadBytesPerSecond\)/);
    assert.match(upload, /text: ResourceUsage\.formatRate\(ResourceUsage\.uploadBytesPerSecond\)/);
});

// Four readings where the CPU card has one. A 36px figure twice over would leave the peak and
// the total nowhere to go and take the height off the plot, which is the element the whole
// destination is built around.
test("the current rates are stated quietly enough to leave room for the plot", () => {
    const size = Number(/readonly property int rateSize: (\d+)/.exec(networkCard)[1]);
    assert.ok(size < 36, `current rate at ${size}px is the size of a single-figure headline`);

    const [rate] = blocks(networkCard, "component CurrentRate: Text");
    assert.match(rate, /font\.pixelSize: root\.rateSize/);
    assert.match(rate, /color: Appearance\.colors\.colOnLayer2/);

    // The supporting readings sit in a fixed column, so the number in front of them changing
    // width every second does not slide them back and forth under the reader.
    assert.match(rate, /width: Math\.max\(implicitWidth, rateColumn\.width\)/);
    const [column] = blocks(networkCard, "TextMetrics");
    assert.match(column, /text: "1023\.9 KiB\/s"/);
    assert.match(column, /font\.pixelSize: root\.rateSize/);

    // The supporting pair is subtext: a peak and a counter are context for the current
    // reading, not three readings competing at one weight.
    const [past] = blocks(networkCard, "component PastReadings: Text");
    assert.match(past, /font\.pixelSize: Appearance\.font\.pixelSize\.smaller/);
    assert.match(past, /color: Appearance\.colors\.colSubtext/);
});

// The peak is the fastest second of the minute on the plot, so the plot's own "Last 60
// seconds" is what dates it. The counter is not from that window at all, and says so — left
// unqualified beside the peak it would read as another number about the same minute.
test("each direction states its window peak and its counter since boot", () => {
    const [download, upload] = blocks(networkCard, "PastReadings");
    assert.match(download, /text: root\.pastText\(root\.downloadPeak, ResourceUsage\.downloadTotalBytes\)/);
    assert.match(upload, /text: root\.pastText\(root\.uploadPeak, ResourceUsage\.uploadTotalBytes\)/);

    const [pastText] = blocks(networkCard, "function pastText(peakBytesPerSecond: var, totalBytes: var): string");
    assert.match(pastText, /peak \$\{ResourceUsage\.formatRate\(peakBytesPerSecond\)\}/);
    assert.match(pastText, /\$\{ResourceUsage\.formatBytes\(totalBytes\)\} since boot/);

    // Both peaks come off the same pass over the window that chooses the shared scale, so the
    // number stated and the number scaled to cannot disagree.
    const [update] = blocks(networkCard, "function updateWindow(): void");
    assert.match(update, /root\.downloadPeak = Ceiling\.peakRate\(download\)/);
    assert.match(update, /root\.uploadPeak = Ceiling\.peakRate\(upload\)/);
});

// An interface appearing or going away resets the counters the rate is a delta of. The
// direction that lost its baseline has no reading until the next one, and substituting a zero
// would draw a topology change as traffic stopping.
test("a rebaselining direction reads as an em dash without disturbing its history", () => {
    // `ResourceUsage` publishes null for that direction and the service's own formatter is
    // what turns null into an em dash — the card does not get to decide on a stand-in.
    assert.match(networkCard, /text: ResourceUsage\.formatRate\(ResourceUsage\.downloadBytesPerSecond\)/);
    assert.doesNotMatch(networkCard, /\|\| 0|\?\? 0/);

    // The row it wrote is NaN, which is a break in the line rather than a reason to throw
    // away the minute either direction already has.
    assert.doesNotMatch(networkCard, /clearHistory|history\.clear/);
    const [series] = blocks(networkCard, "TimeseriesPlot");
    assert.match(series, /primaryRole: "downloadBytesPerSecond"/);
    assert.match(series, /secondaryRole: "uploadBytesPerSecond"/);
});

// Throughput has no capacity to be plotted against, so the scale comes from the traffic — and
// a scale that moves is a way for the card to lie, because a rescale and a change in traffic
// draw the same movement. Stating the ceiling is what separates them.
test("both series share one damped ceiling, and the card says what it is", () => {
    assert.match(networkCard, /property real ceiling: Ceiling\.FLOOR_BYTES_PER_SECOND/);
    assert.match(networkCard, /Ceiling\.settleCeiling\(root\.ceiling, Ceiling\.ceilingTarget\(root\.downloadPeak, root\.uploadPeak\)\)/);

    const [series] = blocks(networkCard, "TimeseriesPlot");
    assert.match(series, /maximum: root\.ceiling/);
    assert.match(series, /ceilingLabel: ResourceUsage\.formatRate\(root\.ceiling\)/);

    const [connections] = blocks(networkCard, "Connections");
    assert.match(connections, /target: ResourceUsage/);
    assert.match(connections, /function onHistoryUpdated\(\): void \{\s*root\.updateWindow\(\);/);
});

test("a moving ceiling is stated where it does not compete with the lines", () => {
    const [label] = blocks(plot, "Text").filter(text => text.includes("root.ceilingLabel"));

    assert.match(label, /anchors\.top: parent\.top/);
    assert.match(label, /anchors\.right: parent\.right/);
    assert.match(label, /font\.pixelSize: Appearance\.font\.pixelSize\.smallest/);
    assert.match(label, /color: Appearance\.colors\.colSubtext/);
    // Nothing to state on a plot whose ceiling is a fixed 100%.
    assert.match(label, /visible: !root\.collecting && root\.ceilingLabel !== ""/);
});

// Spec #150 ruled out network totals; they are here because the shell's owner asked for them
// after seeing the card. Pinned as the exact set the card reads, so the readings on it stay a
// decision rather than a drift, and so the departure from the spec is visible from the tests.
test("the network card reads current rates, their history, and the boot counters", () => {
    const referenced = [...new Set(networkCard.match(/ResourceUsage\.\w+/g))].sort();

    assert.deepEqual(referenced, [
        "ResourceUsage.downloadBytesPerSecond",
        "ResourceUsage.downloadTotalBytes",
        "ResourceUsage.formatBytes",
        "ResourceUsage.formatRate",
        "ResourceUsage.history",
        "ResourceUsage.uploadBytesPerSecond",
        "ResourceUsage.uploadTotalBytes"
    ]);
});

test("download and upload keep one colour between their line and their key", () => {
    const [series] = blocks(networkCard, "TimeseriesPlot");

    assert.match(series, /primaryColor: Appearance\.colors\.colPrimary/);
    assert.match(series, /secondaryColor: Appearance\.colors\.colTertiary/);
    assert.match(series, /primaryKey: "Download"/);
    assert.match(series, /secondaryKey: "Upload"/);
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
