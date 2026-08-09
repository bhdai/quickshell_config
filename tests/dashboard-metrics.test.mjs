import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";
import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const dashboardDir = path.join(repoRoot, "modules", "dashboard");
const metrics = loadQmlJs(path.join(dashboardDir, "dashboard_metrics.js"), ["MARGIN", "PAD", "TABBAR_H", "GAP", "cardWidth", "cardHeight", "HEADER_H", "COL_GAP", "TILE", "TILE_COL_W", "BODY_H", "CALENDAR_COL_W", "CALENDAR_PANE_W", "CALENDAR_PANE_H", "GRID_COLUMNS", "GRID_ROWS", "CELL_W", "CELL_H", "CELL_GAP_X", "CELL_GAP_Y", "WALLPAPER_PANE_W", "WALLPAPER_PANE_H", "PERFORMANCE_PANE_W", "PERFORMANCE_PANE_H", "CARD_GAP", "PERFORMANCE_ROW_H", "PERFORMANCE_TOP_CARD_W", "PERFORMANCE_CARD_PAD", "PERFORMANCE_CARD", "CANVAS", "TRACK_START", "TRACK_W", "WINDOW_W", "WINDOW_H"]);

test("the chrome is what the card adds around whatever pane is showing", () => {
    assert.equal(metrics.MARGIN, 10);
    assert.equal(metrics.PAD, 12);
    assert.equal(metrics.TABBAR_H, 64);
    assert.equal(metrics.GAP, 8);

    assert.equal(metrics.cardWidth(100), 100 + 2 * metrics.PAD);
    assert.equal(metrics.cardHeight(100), 100 + 2 * metrics.PAD + metrics.TABBAR_H + metrics.GAP);
});

// The point of per-destination sizing: every tab names its canvas, and the chrome around
// them is the same.
test("each destination names its own canvas", () => {
    assert.equal(metrics.CALENDAR_PANE_W, 872);
    assert.equal(metrics.CALENDAR_PANE_H, 428);
    assert.equal(metrics.cardWidth(metrics.CALENDAR_PANE_W), 896);
    assert.equal(metrics.cardHeight(metrics.CALENDAR_PANE_H), 524);

    assert.equal(metrics.WALLPAPER_PANE_W, 676);
    assert.equal(metrics.WALLPAPER_PANE_H, 424);
    assert.equal(metrics.cardWidth(metrics.WALLPAPER_PANE_W), 700);
    assert.equal(metrics.cardHeight(metrics.WALLPAPER_PANE_H), 520);

    assert.equal(metrics.PERFORMANCE_PANE_W, 872);
    assert.equal(metrics.PERFORMANCE_PANE_H, 428);
    assert.equal(metrics.cardWidth(metrics.PERFORMANCE_PANE_W), 896);
    assert.equal(metrics.cardHeight(metrics.PERFORMANCE_PANE_H), 524);

    assert.notEqual(metrics.CALENDAR_PANE_W, metrics.WALLPAPER_PANE_W);
});

test("the transition track gives every destination its fixed-width segment", () => {
    assert.deepEqual(metrics.TRACK_START, {
        dashboard: 0,
        wallpaper: 872,
        performance: 1548
    });
    assert.equal(metrics.TRACK_W, 2420);
});

// Four cards on one canvas, so the pane is divided rather than filled: the two rows and the
// two cards in the top row have to come out at the pane's own edges, gaps included.
test("the performance cards divide the pane they sit on", () => {
    assert.equal(metrics.CARD_GAP, 12);
    assert.equal(metrics.PERFORMANCE_ROW_H, 208);
    assert.equal(metrics.PERFORMANCE_TOP_CARD_W, 430);

    assert.equal(2 * metrics.PERFORMANCE_ROW_H + metrics.CARD_GAP, metrics.PERFORMANCE_PANE_H);
    assert.equal(2 * metrics.PERFORMANCE_TOP_CARD_W + metrics.CARD_GAP, metrics.PERFORMANCE_PANE_W);
});

test("the CPU card is the top-left of the performance pane", () => {
    assert.deepEqual(metrics.PERFORMANCE_CARD.cpu, {
        x: 0,
        y: 0,
        width: 430,
        height: 208
    });
});

test("the calendar body is the pane under a full-width 72px header", () => {
    assert.equal(metrics.HEADER_H, 72);
    assert.equal(metrics.BODY_H, 348);
    assert.equal(metrics.CALENDAR_PANE_H, metrics.HEADER_H + metrics.GAP + metrics.BODY_H);
});

// Six tiles in three columns of two, square. The tile edge is what the tile column's width
// and the body's height are both built from, so it is the one number that can be moved.
test("the 3x2 tile grid comes out square", () => {
    assert.equal(metrics.TILE, 168);
    assert.equal(metrics.COL_GAP, 12);

    const tileW = (metrics.TILE_COL_W - 2 * metrics.COL_GAP) / 3;
    const tileH = (metrics.BODY_H - metrics.COL_GAP) / 2;

    assert.equal(tileW, metrics.TILE);
    assert.equal(tileH, metrics.TILE);
});

test("the calendar column keeps its width and the tiles take the rest", () => {
    assert.equal(metrics.CALENDAR_COL_W, 332);
    assert.equal(metrics.TILE_COL_W, 528);
    assert.equal(metrics.CALENDAR_COL_W + metrics.COL_GAP + metrics.TILE_COL_W, metrics.CALENDAR_PANE_W);
});

// Grid A of the accepted prototype, now read the other way round: the cell is declared and
// the destination is as wide as four of them.
test("the wallpaper pane is exactly the 4x4 of 160x100 cells it shows", () => {
    assert.equal(metrics.GRID_COLUMNS, 4);
    assert.equal(metrics.GRID_ROWS, 4);
    assert.equal(metrics.CELL_W, 160);
    assert.equal(metrics.CELL_H, 100);
    assert.equal(metrics.CELL_GAP_X, 12);
    assert.equal(metrics.CELL_GAP_Y, 8);

    assert.equal(metrics.GRID_COLUMNS * metrics.CELL_W + (metrics.GRID_COLUMNS - 1) * metrics.CELL_GAP_X, metrics.WALLPAPER_PANE_W);
    assert.equal(metrics.GRID_ROWS * metrics.CELL_H + (metrics.GRID_ROWS - 1) * metrics.CELL_GAP_Y, metrics.WALLPAPER_PANE_H);
});

test("the pane track supplies continuity without a cut or fade", () => {
    const card = read(dashboardDir, "DashboardCard.qml");

    assert.doesNotMatch(card, /Behavior on opacity|TAB_FADE_MS/);
    assert.doesNotMatch(read(dashboardDir, "dashboard_metrics.js"), /TAB_FADE_MS/);
});

test("the transition lifecycle is observable through read-only card properties", () => {
    const card = read(dashboardDir, "DashboardCard.qml");

    assert.match(card, /readonly property bool transitionMotionRunning: trackMotion\.running/);
    assert.match(card, /readonly property real transitionTrackPosition: track\.x/);
    assert.match(card, /readonly property real targetTrackPosition:/);
    assert.match(card, /readonly property var residentDestinationKeys:/);
    assert.match(card, /readonly property Item indicatorItem: tabBar\.indicatorItem/);
});

// The card is chrome around the pane. A card that took its size from anything else would put
// the destinations back on one shared canvas.
test("the card follows the pane", () => {
    const card = read(dashboardDir, "DashboardCard.qml");

    assert.match(card, /readonly property real settledWidth: Metrics\.cardWidth\(Metrics\.CANVAS\[transitionState\.destination\]\.width\)/);
    assert.match(card, /implicitWidth: root\.settledWidth\b/);
    assert.match(card, /implicitHeight: Metrics\.cardHeight\(Metrics\.CANVAS\[transitionState\.destination\]\.height\)/);
});

// The window is the one thing that must not follow the card: a layer surface bound to an
// animating size is re-committed and re-centred every frame, which shows as a flicker around
// the edges. It is fixed at the largest destination, and the mask is what stops the resulting
// transparent border from eating the clicks that dismiss the dashboard.
test("the window holds still at the largest destination and masks to the card", () => {
    assert.equal(metrics.WINDOW_W, Math.max(metrics.cardWidth(metrics.CALENDAR_PANE_W), metrics.cardWidth(metrics.WALLPAPER_PANE_W), metrics.cardWidth(metrics.PERFORMANCE_PANE_W)) + 2 * metrics.MARGIN);
    assert.equal(metrics.WINDOW_H, Math.max(metrics.cardHeight(metrics.CALENDAR_PANE_H), metrics.cardHeight(metrics.WALLPAPER_PANE_H), metrics.cardHeight(metrics.PERFORMANCE_PANE_H)) + 2 * metrics.MARGIN);
    // The calendar is now the widest destination; before the tiles went three abreast the
    // wallpaper grid was, so this is the tab whose card the window is cut to.
    assert.equal(metrics.WINDOW_W, 916);
    assert.equal(metrics.WINDOW_H, 544);

    const [panel] = blocks(read(dashboardDir, "Dashboard.qml"), "PanelWindow");

    assert.match(panel, /implicitWidth: Metrics\.WINDOW_W\b/);
    assert.match(panel, /implicitHeight: Metrics\.WINDOW_H\b/);
    assert.match(panel, /mask: Region \{\s*item: card\s*\}/);
    // Centring would walk the card up and down the window on every resize.
    assert.match(panel, /anchors\.top: parent\.top/);
    assert.doesNotMatch(panel, /anchors\.centerIn/);
    assert.match(panel, /WlrLayershell\.namespace: "quickshell:dashboard"/);
});

// Between destinations the card resizes; within one it must not. A pane that took its size
// from its content would put the card on a spring — a month with a sixth row, a longer
// condition string or a sparse library would each move it.
test("a pane takes the canvas its destination named rather than growing to its content", () => {
    assert.match(read(dashboardDir, "DashboardPane.qml"), /implicitWidth: Metrics\.CANVAS\.dashboard\.width\b/);
    assert.match(read(dashboardDir, "DashboardPane.qml"), /implicitHeight: Metrics\.CANVAS\.dashboard\.height\b/);
    assert.match(read(dashboardDir, "WallpaperPane.qml"), /implicitWidth: Metrics\.CANVAS\.wallpaper\.width\b/);
    assert.match(read(dashboardDir, "WallpaperPane.qml"), /implicitHeight: Metrics\.CANVAS\.wallpaper\.height\b/);
    assert.match(read(dashboardDir, "PerformancePane.qml"), /implicitWidth: Metrics\.CANVAS\.performance\.width\b/);
    assert.match(read(dashboardDir, "PerformancePane.qml"), /implicitHeight: Metrics\.CANVAS\.performance\.height\b/);
});

// The window is sized from CANVAS, so a destination the map does not know about is one the
// window was never sized for. Every tab the card can build has to have an entry.
test("every destination the card can reach names a canvas", () => {
    const card = read(dashboardDir, "DashboardCard.qml");
    const reachable = [...card.matchAll(/case "(\w+)":/g)].map(([, name]) => name);

    assert.deepEqual(reachable.sort(), Object.keys(metrics.CANVAS).sort());
});

// The card is rebuilt on every open, so an ungated Behavior animates it up from nothing each
// time rather than only between tabs.
test("the resize animates between destinations but not into the first one", () => {
    const card = read(dashboardDir, "DashboardCard.qml");

    const gates = [...card.matchAll(/Behavior on implicit(?:Width|Height) \{\s*enabled: ([^\n]*)/g)].map(([, gate]) => gate);

    assert.deepEqual(gates, ["root.placed", "root.placed"]);
    assert.equal(card.match(/Behavior on implicit(?:Width|Height)/g)?.length, gates.length);
    assert.match(card, /Qt\.callLater\(\(\) => root\.placed = true\)/);
});
