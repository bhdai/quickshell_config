import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";
import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const dashboardDir = path.join(repoRoot, "modules", "dashboard");
const metrics = loadQmlJs(path.join(dashboardDir, "dashboard_metrics.js"), ["WINDOW_W", "WINDOW_H", "MARGIN", "CARD_W", "CARD_H", "PAD", "TABBAR_H", "GAP", "PANE_W", "PANE_H", "HEADER_H", "BODY_H", "COL_W", "COL_GAP", "TAB_FADE_MS"]);

// #96's canvas. These are derived rather than restated so a change to the padding cannot
// leave the pane claiming a width the card does not have, but the derivation has to land
// on the numbers the accepted prototype was measured at.
test("the dashboard is the fixed size the prototype settled on", () => {
    assert.equal(metrics.WINDOW_W, 720);
    assert.equal(metrics.WINDOW_H, 527);
    assert.equal(metrics.CARD_W, 700);
    assert.equal(metrics.CARD_H, 507);
    assert.equal(metrics.PANE_W, 676);
    assert.equal(metrics.PANE_H, 427);
});

test("the window is the card plus its outer margin", () => {
    assert.equal(metrics.MARGIN, 10);
    assert.equal(metrics.WINDOW_W, metrics.CARD_W + 2 * metrics.MARGIN);
    assert.equal(metrics.WINDOW_H, metrics.CARD_H + 2 * metrics.MARGIN);
});

test("the pane is what the card has left after its padding, tab bar and gap", () => {
    assert.equal(metrics.PAD, 12);
    assert.equal(metrics.TABBAR_H, 48);
    assert.equal(metrics.GAP, 8);
    assert.equal(metrics.PANE_W, metrics.CARD_W - 2 * metrics.PAD);
    assert.equal(metrics.PANE_H, metrics.CARD_H - 2 * metrics.PAD - metrics.TABBAR_H - metrics.GAP);
});

test("the calendar body is the pane under a full-width 72px header", () => {
    assert.equal(metrics.HEADER_H, 72);
    assert.equal(metrics.BODY_H, 347);
    assert.equal(metrics.BODY_H, metrics.PANE_H - metrics.HEADER_H - metrics.GAP);
});

test("the calendar and the tile grid are equal columns of the pane", () => {
    assert.equal(metrics.COL_GAP, 12);
    assert.equal(metrics.COL_W, 332);
    assert.equal(2 * metrics.COL_W + metrics.COL_GAP, metrics.PANE_W);
});

// Six tiles in two columns of three, at the size #96 called approximately 160 x 107.
test("the 2x3 tile grid fits the column at the accepted tile size", () => {
    const tileW = (metrics.COL_W - metrics.COL_GAP) / 2;
    const tileH = (metrics.BODY_H - 2 * metrics.COL_GAP) / 3;

    assert.equal(tileW, 160);
    assert.ok(Math.abs(tileH - 107) < 1, `tile height ${tileH} is not about 107`);
});

test("the pane fade is the prototype's 120ms, and zero is the hard cut", () => {
    assert.equal(metrics.TAB_FADE_MS, 120);

    const card = read(dashboardDir, "DashboardCard.qml");
    assert.match(card, /duration: Metrics\.TAB_FADE_MS\b/);
});

// A tab that resized the pane would defeat the whole fixed canvas, so the sizes are set
// from the metrics rather than grown from whatever the active pane implies.
test("the card and pane take their size from the metrics, not from their content", () => {
    const card = read(dashboardDir, "DashboardCard.qml");

    assert.match(card, /implicitWidth: Metrics\.CARD_W\b/);
    assert.match(card, /implicitHeight: Metrics\.CARD_H\b/);
    assert.match(card, /width: Metrics\.PANE_W\b/);
    assert.match(card, /height: Metrics\.PANE_H\b/);
});

test("the window is fixed at the metrics and keeps the dashboard namespace", () => {
    const [panel] = blocks(read(dashboardDir, "Dashboard.qml"), "PanelWindow");

    assert.match(panel, /implicitWidth: Metrics\.WINDOW_W\b/);
    assert.match(panel, /implicitHeight: Metrics\.WINDOW_H\b/);
    assert.match(panel, /WlrLayershell\.namespace: "quickshell:dashboard"/);
});
