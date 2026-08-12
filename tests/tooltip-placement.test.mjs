import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { place } = loadQmlJs(
    new URL("../modules/common/widgets/TooltipPlacement.js", import.meta.url),
    ["place"],
);

const screen = { x: 0, y: 0, width: 1920, height: 1080 };
const gap = 4;

const rect = (x, y, width, height) => ({ x, y, width, height });
const size = (width, height) => ({ width, height });

const right = placed => placed.x + 200;

test("centres the tooltip on its anchor", () => {
    const placed = place(rect(900, 500, 30, 30), size(200, 24), screen, "above", gap);
    assert.equal(placed.x, 900 + 15 - 100);
});

test("sits gap above the anchor when preferred above", () => {
    const placed = place(rect(900, 500, 30, 30), size(200, 24), screen, "above", gap);
    assert.equal(placed.y, 500 - gap - 24);
    assert.equal(placed.side, "above");
});

test("sits gap below the anchor when preferred below", () => {
    const placed = place(rect(900, 500, 30, 30), size(200, 24), screen, "below", gap);
    assert.equal(placed.y, 500 + 30 + gap);
    assert.equal(placed.side, "below");
});

test("flips below when there is no room above", () => {
    const anchor = rect(900, 2, 30, 30);
    const placed = place(anchor, size(200, 24), screen, "above", gap);
    assert.equal(placed.side, "below");
    assert.equal(placed.y, 2 + 30 + gap);
});

test("flips above when there is no room below", () => {
    const anchor = rect(900, 1040, 30, 30);
    const placed = place(anchor, size(200, 24), screen, "below", gap);
    assert.equal(placed.side, "above");
    assert.equal(placed.y, 1040 - gap - 24);
});

// A bar item at the top of the screen is the case the whole "below" default exists for: it
// must not flip back up into the bar just because there is technically room there.
test("keeps a bar anchor's tooltip below when it fits", () => {
    const placed = place(rect(900, 0, 30, 30), size(200, 24), screen, "below", gap);
    assert.equal(placed.side, "below");
});

test("does not flip when neither side fits, keeping the requested side", () => {
    const tall = { x: 0, y: 0, width: 1920, height: 60 };
    const placed = place(rect(900, 20, 20, 20), size(200, 40), tall, "above", gap);
    assert.equal(placed.side, "above");
});

test("aligns to the anchor's left edge rather than clipping off screen left", () => {
    const anchor = rect(20, 500, 30, 30);
    const placed = place(anchor, size(200, 24), screen, "above", gap);
    assert.equal(placed.x, 20);
    assert.ok(placed.x >= screen.x);
});

test("aligns to the anchor's right edge rather than clipping off screen right", () => {
    const anchor = rect(1870, 500, 30, 30);
    const placed = place(anchor, size(200, 24), screen, "above", gap);
    assert.equal(placed.x, 1870 + 30 - 200);
    assert.ok(right(placed) <= screen.x + screen.width);
});

// For any anchor that is itself on screen, aligning to the anchor's edge is already enough —
// the clamp never fires. It exists for the cases that alignment cannot solve: a tooltip wider
// than the screen, or an anchor hanging off the edge.
test("start-aligns rather than clamping for an anchor hard against the edge", () => {
    const placed = place(rect(4, 500, 30, 30), size(200, 24), screen, "above", gap);
    assert.equal(placed.x, 4);
});

test("clamps a tooltip wider than the screen to the left edge", () => {
    const placed = place(rect(900, 500, 30, 30), size(2400, 24), screen, "above", gap);
    assert.equal(placed.x, screen.x);
});

test("clamps an anchor that hangs off the right edge", () => {
    const placed = place(rect(1900, 500, 200, 30), size(200, 24), screen, "above", gap);
    assert.equal(right(placed), screen.x + screen.width);
});

// Multi-monitor: the screen rect does not start at the origin, and every bound has to be
// expressed relative to it or tooltips land on the wrong output.
test("respects a screen whose origin is not zero", () => {
    const secondary = { x: 1920, y: 0, width: 1920, height: 1080 };
    const placed = place(rect(1924, 500, 30, 30), size(200, 24), secondary, "above", gap);
    assert.equal(placed.x, 1924);

    const centred = place(rect(2800, 500, 30, 30), size(200, 24), secondary, "above", gap);
    assert.equal(centred.x, 2800 + 15 - 100);
});

test("flips against a screen whose vertical origin is not zero", () => {
    const lower = { x: 0, y: 1080, width: 1920, height: 1080 };
    const placed = place(rect(900, 1082, 30, 30), size(200, 24), lower, "above", gap);
    assert.equal(placed.side, "below");
});

test("a tooltip exactly filling the width still lands on screen", () => {
    const placed = place(rect(0, 500, 10, 10), size(1920, 24), screen, "above", gap);
    assert.equal(placed.x, 0);
    assert.equal(placed.x + 1920, screen.width);
});
