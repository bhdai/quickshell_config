import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const plot = loadQmlJs(path.join(repoRoot, "modules", "dashboard", "timeseries_plot.js"), [
    "MIN_SAMPLES",
    "sampleX",
    "sampleY",
    "seriesSegments",
    "areaPolygon"
]);

const { MIN_SAMPLES, sampleX, sampleY, seriesSegments, areaPolygon } = plot;

// The window is sixty seconds wide whether or not sixty samples have arrived yet. Anchoring
// the newest sample to the right edge and stepping left by one fixed stride is what keeps a
// second the same distance everywhere; stretching whatever has been collected across the
// full width would make a three-sample plot claim a minute of history.
test("a sample's x is its age, not its share of the width", () => {
    assert.equal(sampleX(59, 60, 60, 590), 590);
    assert.equal(sampleX(0, 60, 60, 590), 0);
    assert.equal(sampleX(58, 60, 60, 590), 580);

    // Three samples into a minute: still one stride apart, still ending at the right edge.
    assert.equal(sampleX(2, 3, 60, 590), 590);
    assert.equal(sampleX(1, 3, 60, 590), 580);
    assert.equal(sampleX(0, 3, 60, 590), 570);
});

test("a sample's y is its fraction of the caller's scale, measured down from the top", () => {
    assert.equal(sampleY(0, 1, 100), 100);
    assert.equal(sampleY(1, 1, 100), 0);
    assert.equal(sampleY(0.25, 1, 100), 75);

    // The caller owns the scale, so a reading past it is drawn at the ceiling rather than
    // silently rescaling the plot under the reader.
    assert.equal(sampleY(1.5, 1, 100), 0);
    assert.equal(sampleY(-0.5, 1, 100), 100);
    // A scale that has collapsed cannot divide; the series flattens onto the baseline.
    assert.equal(sampleY(0.5, 0, 100), 100);
});

test("a whole series is one segment of points", () => {
    const segments = seriesSegments([0, 0.5, 1], 1, 60, 590, 100);

    assert.equal(segments.length, 1);
    assert.deepEqual(segments[0], [
        { x: 570, y: 100 },
        { x: 580, y: 50 },
        { x: 590, y: 0 }
    ]);
});

// The plot draws no invented history: a gap is a break, never a bridge between the readings
// either side of it.
test("a gap breaks the line rather than being drawn through", () => {
    const segments = seriesSegments([0, 0.5, NaN, 1, 0.5], 1, 60, 590, 100);

    assert.equal(segments.length, 2);
    assert.deepEqual(segments[0].map(point => point.x), [550, 560]);
    assert.deepEqual(segments[1].map(point => point.x), [580, 590]);
});

// A polyline needs two points. One reading with a gap either side has no line to draw, and
// drawing a dot for it would put a mark on the plot that the geometry cannot place in time.
test("a reading alone between two gaps draws nothing", () => {
    assert.deepEqual(seriesSegments([NaN, 0.5, NaN], 1, 60, 590, 100), []);
    assert.deepEqual(seriesSegments([0.5], 1, 60, 590, 100), []);
    assert.deepEqual(seriesSegments([], 1, 60, 590, 100), []);
});

test("anything that is not a finite reading is a gap", () => {
    assert.deepEqual(seriesSegments([null, undefined, Infinity, 0.5, 0.5], 1, 60, 590, 100).length, 1);
});

test("two samples is the least that can be drawn", () => {
    assert.equal(MIN_SAMPLES, 2);
    assert.equal(seriesSegments([0.5, 0.5], 1, 60, 590, 100).length, 1);
});

// The fill is the same line closed down to the baseline, so it can never disagree with the
// stroke about where the reading was.
test("the area under a segment closes onto the baseline at both ends", () => {
    const [segment] = seriesSegments([0, 0.5, 1], 1, 60, 590, 100);

    assert.deepEqual(areaPolygon(segment, 100), [
        { x: 570, y: 100 },
        { x: 570, y: 100 },
        { x: 580, y: 50 },
        { x: 590, y: 0 },
        { x: 590, y: 100 }
    ]);
});
