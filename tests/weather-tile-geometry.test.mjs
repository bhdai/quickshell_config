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
    "SUN_SAMPLES",
    "waterLevel",
    "waveLine",
    "sunPath",
    "sunMarker"
]);

const {
    WAVE_WAVELENGTH,
    WAVE_AMPLITUDE,
    WAVE_PHASE,
    WAVE_SAMPLES,
    SUN_SAMPLES,
    waterLevel,
    waveLine,
    sunPath,
    sunMarker
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

test("sunPath rises from the horizon to a midday peak and back", () => {
    const points = sunPath(160, 40, 8);
    assert.equal(points.length, 9);
    near(points[0].x, 0, "starts at the left edge");
    near(points[0].y, 40, "starts on the horizon");
    near(points[4].x, 80, "peaks at the midpoint");
    near(points[4].y, 0, "peaks at the top of the box");
    near(points[8].x, 160, "ends at the right edge");
    near(points[8].y, 40, "ends on the horizon");
});

test("sunPath is symmetric and never leaves the box", () => {
    const samples = 24;
    const points = sunPath(200, 50, samples);
    for (let i = 0; i <= samples; i++) {
        assert.ok(points[i].y >= 0 && points[i].y <= 50, `point ${i} stays inside the box`);
        near(points[i].y, points[samples - i].y, `point ${i} mirrors its opposite`);
    }
});

test("sunPath climbs monotonically to the peak", () => {
    const points = sunPath(200, 50, 20);
    for (let i = 1; i <= 10; i++)
        assert.ok(points[i].y < points[i - 1].y, `point ${i} is higher than the one before it`);
});

test("sunMarker rides the same curve the path draws", () => {
    const samples = 12;
    const points = sunPath(120, 30, samples);
    for (let i = 0; i <= samples; i++) {
        const marker = sunMarker(120, 30, i / samples);
        near(marker.x, points[i].x, `marker x at ${i}`);
        near(marker.y, points[i].y, `marker y at ${i}`);
    }
});

test("sunMarker rests on the horizon through the night", () => {
    // dayProgress() clamps, so both ends of the span are "not daylight" and the dot parks
    // at the horizon rather than running off the curve.
    const dawn = sunMarker(160, 40, 0);
    near(dawn.x, 0, "parked at sunrise");
    near(dawn.y, 40, "parked on the horizon at sunrise");

    const dusk = sunMarker(160, 40, 1);
    near(dusk.x, 160, "parked at sunset");
    near(dusk.y, 40, "parked on the horizon at sunset");
});

test("the tuned constants are usable sample counts and a positive wave", () => {
    assert.ok(Number.isInteger(WAVE_SAMPLES) && WAVE_SAMPLES > 0);
    assert.ok(Number.isInteger(SUN_SAMPLES) && SUN_SAMPLES > 0);
    assert.ok(WAVE_AMPLITUDE > 0);
    assert.ok(WAVE_WAVELENGTH > 0);
});
