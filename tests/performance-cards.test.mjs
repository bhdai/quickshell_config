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
const storageCard = read(dashboardDir, "StorageCard.qml");
const plot = read(dashboardDir, "TimeseriesPlot.qml");

// The pane is a fixed canvas divided between cards, so where a card sits is a fact about
// the destination rather than about the card. Written inline, four cards' worth of these
// numbers could no longer be shown to add up to the pane.
test("a card is placed at the rectangle the metrics module names for it", () => {
    for (const [type, name] of [["CpuCard", "cpu"], ["MemoryCard", "memory"], ["NetworkCard", "network"], ["StorageCard", "storage"]]) {
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

    // One component used twice, so the two directions cannot drift into different weights:
    // what differs between them is which way the arrow points, which colour role carries it,
    // and the rate itself.
    const [download, upload] = blocks(networkCard, "DirectionReading");
    assert.match(download, /arrow: "arrow_downward"/);
    assert.match(download, /rate: ResourceUsage\.formatRate\(ResourceUsage\.downloadBytesPerSecond\)/);
    assert.match(download, /container: Appearance\.colors\.colPrimaryContainer/);
    assert.match(upload, /arrow: "arrow_upward"/);
    assert.match(upload, /rate: ResourceUsage\.formatRate\(ResourceUsage\.uploadBytesPerSecond\)/);
    assert.match(upload, /container: Appearance\.colors\.colTertiaryContainer/);
});

// A direction is a thing on this card, not a line of text about one: the chip is what makes
// the pair read as two flows, and it is where the card spends its one piece of shape.
test("each direction is carried by a chip in its own colour role", () => {
    const [reading] = blocks(networkCard, "component DirectionReading: Row");
    const [chip] = blocks(reading, "Rectangle");

    assert.match(chip, /radius: Appearance\.rounding\.full/);
    assert.match(chip, /implicitWidth: root\.chipSize/);
    assert.match(chip, /color: reading\.container/);

    // On-container against container is the pairing the palette guarantees legible. The line
    // colour on its own container fill would be a fresh contrast gamble on every wallpaper.
    const [glyph] = blocks(chip, "MaterialSymbol");
    assert.match(glyph, /color: reading\.onContainer/);
    assert.match(glyph, /fill: 1/);
});

// Two current readings where the CPU card has one, and a plot that is the point of the
// destination: a single-figure headline's size twice over would take the height off the plot.
test("the current rates are stated quietly enough to leave room for the plot", () => {
    const size = Number(/readonly property int rateSize: (\d+)/.exec(networkCard)[1]);
    assert.ok(size < 36, `current rate at ${size}px is the size of a single-figure headline`);

    const [reading] = blocks(networkCard, "component DirectionReading: Row");
    const [rate] = blocks(reading, "Text");
    assert.match(rate, /font\.pixelSize: root\.rateSize/);
    assert.match(rate, /font\.weight: Font\.DemiBold/);
    assert.match(rate, /color: Appearance\.colors\.colOnLayer2/);

    // The rate sits in a fixed column, so a number that changes width every second does not
    // shuffle the upload chip sideways beside it.
    assert.match(rate, /width: Math\.max\(implicitWidth, rateColumn\.width\)/);
    const [column] = blocks(networkCard, "TextMetrics");
    assert.match(column, /text: "1023\.9 KiB\/s"/);
    assert.match(column, /font\.pixelSize: root\.rateSize/);
});

// The peak belongs to the minute the plot draws, so it is stated on that minute's own keys —
// and the keys say which series each number is about by being that series' key.
test("each direction's peak is stated on the key of its line", () => {
    const [series] = blocks(networkCard, "TimeseriesPlot");

    assert.match(series, /primaryValue: ResourceUsage\.formatRate\(root\.downloadPeak\)/);
    assert.match(series, /secondaryValue: ResourceUsage\.formatRate\(root\.uploadPeak\)/);

    // Both peaks come off the same pass over the window that chooses the shared scale, so the
    // number stated and the number scaled to cannot disagree.
    const [update] = blocks(networkCard, "function updateWindow(): void");
    assert.match(update, /root\.downloadPeak = Ceiling\.peakRate\(download\)/);
    assert.match(update, /root\.uploadPeak = Ceiling\.peakRate\(upload\)/);
});

// The counters are the one reading here that is not about the last minute. Left unqualified
// beside readings that are, they would be taken for more of the same.
test("the counters since boot are named for their own window and kept quiet", () => {
    const [counters] = blocks(networkCard, "Column");

    assert.match(counters, /anchors\.right: parent\.right/);
    assert.match(counters, /text: "Since boot"/);
    assert.match(counters, /text: ResourceUsage\.formatBytes\(ResourceUsage\.downloadTotalBytes\)/);
    assert.match(counters, /text: ResourceUsage\.formatBytes\(ResourceUsage\.uploadTotalBytes\)/);

    const [counter] = blocks(networkCard, "component Counter: Text");
    assert.match(counter, /font\.pixelSize: Appearance\.font\.pixelSize\.small/);

    // Arrows from the same font the chips draw from, rather than text arrows a body font may
    // have no glyph for.
    const [arrow] = blocks(networkCard, "component CounterArrow: MaterialSymbol");
    assert.match(arrow, /color: Appearance\.colors\.colSubtext/);
});

// The card reports three different windows. Naming the window on every reading is what turned
// an earlier draft into a table of qualifiers: "peak" twice, "since boot" twice, on four
// numbers. Each window is named once, at the place that already owns it.
test("each window the card reports is named exactly once", () => {
    const shown = [...networkCard.matchAll(/^\s*(?:text|rate|value|primaryValue|secondaryValue|windowLabel):.*$/gm)]
        .flatMap(line => [...line[0].matchAll(/"([^"]*)"/g)].map(literal => literal[1]));

    assert.deepEqual(shown.filter(text => /peak/i.test(text)), ["Peaks · last 60 seconds"]);
    assert.deepEqual(shown.filter(text => /boot/i.test(text)), ["Since boot"]);
});

// An interface appearing or going away resets the counters the rate is a delta of. The
// direction that lost its baseline has no reading until the next one, and substituting a zero
// would draw a topology change as traffic stopping.
test("a rebaselining direction reads as an em dash without disturbing its history", () => {
    // `ResourceUsage` publishes null for that direction and the service's own formatter is
    // what turns null into an em dash — the card does not get to decide on a stand-in.
    assert.match(networkCard, /rate: ResourceUsage\.formatRate\(ResourceUsage\.downloadBytesPerSecond\)/);
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

// The gauge, the figure and the capacity are one reading stated three ways, which is the
// whole card: shape for the glance, percentage for the reading, bytes for the decision.
test("the storage card states root occupancy as a gauge over a percentage", () => {
    assert.match(storageCard, /symbol: "hard_drive"/);
    assert.match(storageCard, /title: "Storage"/);
    assert.match(storageCard, /text: root\.occupancyKnown \? Math\.round\(root\.shownOccupancy \* 100\) : "—"/);
    assert.match(storageCard, /text: ResourceUsage\.formatBytes\(ResourceUsage\.diskUsedBytes\)/);
    assert.match(storageCard, /text: `of \$\{ResourceUsage\.formatBytes\(ResourceUsage\.diskTotalBytes\)\}`/);
});

// A number that moves on the scale of hours dressed up as a timeseries would draw a flat
// line and claim it was worth watching, and the mount is not the reader's to choose.
test("the storage card carries no plot and no mount selector", () => {
    assert.doesNotMatch(storageCard, /TimeseriesPlot|PlotKey|ResourceUsage\.history/);
    assert.doesNotMatch(storageCard, /MouseArea|RippleButton|GroupButton|ComboBox|Repeater/);
});

// One mount, named, so the figure is not read as the machine's whole disk.
test("the filesystem the card reports on is named as root", () => {
    assert.match(storageCard, /text: "Root filesystem"/);
});

// The arc and the percentage encode the same reading, so the card spends its one identity
// colour on the arc and leaves the figure in the ordinary reading colour the other cards use.
test("occupancy is drawn in the card's own colour against the room it has left", () => {
    const [track, active] = blocks(storageCard, "ShapePath");

    assert.match(active, /strokeColor: Appearance\.colors\.colSecondary\b/);
    assert.match(active, /sweepAngle: root\.arcs\.activeSweep/);
    assert.match(track, /strokeColor: Appearance\.colors\.colSecondaryContainer/);
    assert.match(track, /sweepAngle: root\.arcs\.trackSweep/);
    // Material 3's break between the indicator and the track, and the rounded ends that go
    // with it: without the gap the pair reads as one ring in two colours.
    assert.match(track, /startAngle: root\.arcs\.trackStartAngle/);
    for (const path of [track, active])
        assert.match(path, /capStyle: ShapePath\.RoundCap/);

    const [stop] = blocks(storageCard, "Rectangle");
    assert.match(stop, /color: Appearance\.colors\.colSecondary\b/);
    assert.match(stop, /visible: root\.arcs\.stopVisible/);
});

test("the gauge's geometry comes from the pure module rather than the card", () => {
    assert.match(storageCard, /import "storage_gauge\.js" as Gauge/);
    assert.match(storageCard, /Gauge\.occupancyArcs\(root\.shownOccupancy, root\.gaugeRadius\)/);
    assert.match(storageCard, /startAngle: Gauge\.START_ANGLE/);
    assert.doesNotMatch(storageCard, /270|135/);
});

// The pane is destroyed at rest, so this is what the card does on every arrival rather than
// once a session. The overshooting curve is the wrong one here: an arc that ran past its
// reading would report a fuller disk than the machine has, however briefly.
test("the gauge sweeps up to its reading when the destination opens", () => {
    assert.match(storageCard, /property real revealed: 0/);
    assert.match(storageCard, /Component\.onCompleted: root\.revealed = 1/);
    assert.match(storageCard, /shownOccupancy: root\.occupancyKnown \? ResourceUsage\.diskUsedPercentage \* root\.revealed : 0/);

    const [reveal] = blocks(storageCard, "Behavior on revealed");
    assert.match(reveal, /easing\.bezierCurve: Appearance\.animation\.expressiveEffects/);
});

// Free space is not the total less the used — a filesystem holds blocks back that nothing
// here can spend — so it is the one number on this card that is not the gauge restated.
test("the space left is stated as its own reading", () => {
    assert.match(storageCard, /text: `\$\{ResourceUsage\.formatBytes\(ResourceUsage\.diskAvailableBytes\)\} free`/);

    const referenced = [...new Set(storageCard.match(/ResourceUsage\.\w+/g))].sort();
    assert.deepEqual(referenced, [
        "ResourceUsage.diskAvailableBytes",
        "ResourceUsage.diskTotalBytes",
        "ResourceUsage.diskUsedBytes",
        "ResourceUsage.diskUsedPercentage",
        "ResourceUsage.formatBytes"
    ]);
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
    assert.match(plot, /property string windowLabel: "Last 60 seconds"/);
    assert.match(plot, /text: root\.windowLabel/);

    const keys = blocks(plot, "PlotKey");
    assert.deepEqual(keys.map(key => /color: (root\.\w+)/.exec(key)[1]), ["root.primaryColor", "root.secondaryColor"]);
    assert.deepEqual(keys.map(key => /value: (root\.\w+)/.exec(key)[1]), ["root.primaryValue", "root.secondaryValue"]);
});

// A number on a key is about that key's series and no other window than the one the legend
// states. A key that had to name its own window would repeat that name on every line.
test("a key may carry a value, and the legend is what dates it", () => {
    const plotKey = read(dashboardDir, "PlotKey.qml");

    assert.match(plotKey, /property alias value: valueLabel\.text/);
    const [valueLabel] = blocks(plotKey, "Text").filter(text => text.includes("id: valueLabel"));
    assert.match(valueLabel, /visible: valueLabel\.text !== ""/);
    assert.match(valueLabel, /font\.weight: Font\.DemiBold/);
});
