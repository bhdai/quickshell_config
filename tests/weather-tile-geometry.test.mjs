import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const geometry = loadQmlJs(path.join(repoRoot, "modules", "dashboard", "weather_tile_geometry.js"), [
    "WAVE_WAVELENGTH",
    "WAVE_AMPLITUDE",
    "WAVE_PHASE",
    "WAVE_SAMPLES",
    "SUN_HORIZON",
    "SUN_PEAK",
    "SUN_TAIL",
    "SUN_DAY_SPAN",
    "SUN_SAMPLES",
    "SUN_MARKER_RADIUS",
    "SUN_MARKER_LOBES",
    "SUN_MARKER_SCALLOP",
    "SUN_MARKER_SAMPLES",
    "waterLevel",
    "waveLine",
    "sunHorizon",
    "sunRidge",
    "sunPath",
    "sunMarker",
    "scallopedCircle"
]);

const {
    WAVE_WAVELENGTH,
    WAVE_AMPLITUDE,
    WAVE_PHASE,
    WAVE_SAMPLES,
    SUN_HORIZON,
    SUN_PEAK,
    SUN_TAIL,
    SUN_DAY_SPAN,
    SUN_SAMPLES,
    SUN_MARKER_RADIUS,
    SUN_MARKER_LOBES,
    SUN_MARKER_SCALLOP,
    SUN_MARKER_SAMPLES,
    waterLevel,
    waveLine,
    sunHorizon,
    sunRidge,
    sunPath,
    sunMarker,
    scallopedCircle
} = geometry;

const near = (actual, expected, message) => assert.ok(Math.abs(actual - expected) < 1e-9, `${message}: ${actual} is not ${expected}`);

test("waterLevel turns a relative humidity percentage into a fill fraction", () => {
    assert.equal(waterLevel(0), 0);
    near(waterLevel(71), 0.71, "71%");
    assert.equal(waterLevel(100), 1);
});

test("waterLevel clamps readings outside the percentage range", () => {
    assert.equal(waterLevel(140), 1);
    assert.equal(waterLevel(-20), 0);
});

test("waterLevel empties the tile for a reading the service does not have", () => {
    assert.equal(waterLevel(NaN), 0);
    assert.equal(waterLevel(undefined), 0);
    assert.equal(waterLevel(null), 0);
    assert.equal(waterLevel("71"), 0);
});

test("waveLine spans the full width and closes on both edges", () => {
    const points = waveLine(160, 80, 0.5, WAVE_AMPLITUDE, WAVE_WAVELENGTH, WAVE_PHASE, 8);
    assert.equal(points.length, 9);
    assert.equal(points[0].x, 0);
    assert.equal(points[points.length - 1].x, 160);
});

test("waveLine sits the waterline at the fill fraction measured up from the bottom", () => {
    const flat = waveLine(160, 80, 0.25, 0, WAVE_WAVELENGTH, WAVE_PHASE, 4);
    for (const point of flat)
        near(point.y, 60, "flat waterline at 25%");

    near(waveLine(160, 80, 0, 0, WAVE_WAVELENGTH, WAVE_PHASE, 2)[0].y, 80, "empty");
    near(waveLine(160, 80, 1, 0, WAVE_WAVELENGTH, WAVE_PHASE, 2)[0].y, 0, "full");
});

test("waveLine carries one crest and one trough per wavelength", () => {
    // One wavelength across the whole width and no phase offset, so the quarter points land
    // on the zero crossings and the extremes exactly.
    const points = waveLine(160, 80, 0.5, 4, 160, 0, 4);
    near(points[0].y, 40, "start on the waterline");
    near(points[1].y, 44, "quarter");
    near(points[2].y, 40, "half");
    near(points[3].y, 36, "three quarters");
    near(points[4].y, 40, "end on the waterline");
});

test("waveLine shifts with the phase", () => {
    const unshifted = waveLine(160, 80, 0.5, 4, 160, 0, 4);
    const shifted = waveLine(160, 80, 0.5, 4, 160, Math.PI, 4);
    near(shifted[1].y, unshifted[3].y, "half a turn swaps crest and trough");
});

test("the horizon splits the tile, leaving room for the header above and the times below", () => {
    near(sunHorizon(200), 200 * SUN_HORIZON, "horizon at its fraction of the height");
    assert.ok(SUN_HORIZON > 0.5 && SUN_HORIZON < 0.75, "the horizon sits below centre but not against the floor");
    assert.ok(SUN_HORIZON - SUN_PEAK > 0.3, "the peak clears the tile's header row");
});

test("sunRidge peaks at solar noon in the middle of the tile", () => {
    const horizon = sunHorizon(100);
    near(sunRidge(100, 200, 100), horizon - 100 * SUN_PEAK, "peak stands SUN_PEAK above the horizon");
    assert.ok(sunRidge(100, 200, 100) < sunRidge(60, 200, 100), "the midpoint is the highest point");
});

test("sunRidge is symmetric about solar noon", () => {
    for (const offset of [10, 35, 70, 99])
        near(sunRidge(100 - offset, 200, 100), sunRidge(100 + offset, 200, 100), `mirrored at ${offset}`);
});

test("sunRidge climbs monotonically from the left edge to the peak", () => {
    let previous = sunRidge(0, 200, 100);
    for (let x = 5; x <= 100; x += 5) {
        const y = sunRidge(x, 200, 100);
        assert.ok(y < previous, `the ridge is still climbing at ${x}`);
        previous = y;
    }
});

// The hill passing under the horizon rather than meeting it is what makes it read as terrain
// continuing past the tile instead of a chart plotted inside one.
test("sunRidge settles just below the horizon at the tile edges", () => {
    const horizon = sunHorizon(100);
    for (const x of [0, 200]) {
        const y = sunRidge(x, 200, 100);
        assert.ok(y > horizon, `the ridge is under the horizon at ${x}`);
        assert.ok(y - horizon < 100 * SUN_PEAK / 4, `the ridge only dips under the horizon at ${x}`);
    }
});

test("sunPath samples the ridge across the full width", () => {
    const points = sunPath(160, 100, 8);
    assert.equal(points.length, 9);
    near(points[0].x, 0, "starts at the left edge");
    near(points[8].x, 160, "ends at the right edge");
    for (let i = 0; i <= 8; i++)
        near(points[i].y, sunRidge(points[i].x, 160, 100), `sample ${i} is on the ridge`);
});

test("the daylight span is inset from both edges so the tile shows a little night", () => {
    assert.ok(SUN_DAY_SPAN > 0.5 && SUN_DAY_SPAN < 1, "daylight occupies most, not all, of the width");

    const margin = 200 * (1 - SUN_DAY_SPAN) / 2;
    near(sunMarker(200, 100, 0).x, margin, "sunrise sits in from the left edge");
    near(sunMarker(200, 100, 1).x, 200 - margin, "sunset sits in from the right edge");
    near(sunMarker(200, 100, 0.5).x, 100, "solar noon is the midpoint");
});

test("sunMarker rides the ridge rather than floating beside it", () => {
    for (const progress of [0, 0.17, 0.5, 0.83, 1]) {
        const marker = sunMarker(200, 100, progress);
        near(marker.y, sunRidge(marker.x, 200, 100), `marker is on the ridge at ${progress}`);
    }
});

test("sunMarker is at its highest at solar noon and meets the horizon at both ends", () => {
    near(sunMarker(200, 100, 0.5).y, sunHorizon(100) - 100 * SUN_PEAK, "noon is the peak");
    // dayProgress() clamps, so both ends of the span are "not daylight" and the sun parks
    // where the track crosses the horizon rather than running off it.
    for (const progress of [0, 1])
        assert.ok(Math.abs(sunMarker(200, 100, progress).y - sunHorizon(100)) < 100 * SUN_PEAK / 8, `parked on the horizon at ${progress}`);
});

test("scallopedCircle ripples between an inner and an outer radius", () => {
    const points = scallopedCircle(50, 50, 10, SUN_MARKER_LOBES, SUN_MARKER_SCALLOP, SUN_MARKER_SAMPLES);
    assert.equal(points.length, SUN_MARKER_SAMPLES);

    let min = Infinity;
    let max = -Infinity;
    for (const point of points) {
        const r = Math.hypot(point.x - 50, point.y - 50);
        min = Math.min(min, r);
        max = Math.max(max, r);
    }
    near(max, 10 * (1 + SUN_MARKER_SCALLOP), "outer radius");
    near(min, 10 * (1 - SUN_MARKER_SCALLOP), "inner radius");
});

test("scallopedCircle carries one lobe per petal and closes without a duplicate point", () => {
    const lobes = 8;
    const samples = 96;
    const points = scallopedCircle(0, 0, 10, lobes, 0.1, samples);
    const radius = i => Math.hypot(points[(i + samples) % samples].x, points[(i + samples) % samples].y);

    let peaks = 0;
    for (let i = 0; i < samples; i++) {
        if (radius(i) > radius(i - 1) && radius(i) >= radius(i + 1))
            peaks++;
    }
    assert.equal(peaks, lobes);
    assert.notDeepEqual(points[0], points[samples - 1]);
});

test("scallopedCircle degrades to a circle when nothing is scalloped away", () => {
    for (const point of scallopedCircle(0, 0, 7, SUN_MARKER_LOBES, 0, 24))
        near(Math.hypot(point.x, point.y), 7, "every point is on the circle");
});

test("the tuned constants are usable sample counts and a positive wave", () => {
    for (const samples of [WAVE_SAMPLES, SUN_SAMPLES, SUN_MARKER_SAMPLES])
        assert.ok(Number.isInteger(samples) && samples > 0);
    assert.ok(WAVE_AMPLITUDE > 0);
    assert.ok(WAVE_WAVELENGTH > 0);
    assert.ok(SUN_TAIL > 0 && SUN_TAIL < SUN_PEAK);
    assert.ok(SUN_MARKER_RADIUS > 0);
    // A whole number of lobes per turn, or the shape has a seam where it closes.
    assert.ok(Number.isInteger(SUN_MARKER_LOBES) && SUN_MARKER_LOBES > 2);
    assert.equal(SUN_MARKER_SAMPLES % SUN_MARKER_LOBES, 0);
    assert.ok(SUN_MARKER_SCALLOP > 0 && SUN_MARKER_SCALLOP < 0.5);
});

// The fractions above are tuned to one tile size, and nothing in the tile stops the header
// or the clock times from being laid over the landscape if they drift. Both bounds were
// measured offscreen at the size the dashboard's 2x3 grid gives: the header row ends at
// y=27 and the two clock times begin at y=63.
test("the landscape clears the header and the clock times at the size the grid gives a tile", () => {
    const width = 160;
    const height = 107.67;

    assert.ok(sunRidge(width / 2, width, height) > 27 + 8, "the peak stands clear of the header row");
    assert.ok(sunHorizon(height) < 63 - 4, "the clock times stand on the ground, not on the horizon");
});
