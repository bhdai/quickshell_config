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
    "SUN_BASE",
    "SUN_SPREAD",
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
    "sunTrack",
    "isDaylight",
    "sunMarkerReach",
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
    SUN_BASE,
    SUN_SPREAD,
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
    sunTrack,
    isDaylight,
    sunMarkerReach,
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

// The ridge carrying on well under the horizon is the whole reason the lower half reads as
// layered rather than as a block: the terrain is still visibly descending behind the ground.
test("sunRidge keeps descending under the horizon out to the tile edges", () => {
    const horizon = sunHorizon(100);
    for (const x of [0, 200]) {
        const y = sunRidge(x, 200, 100);
        assert.ok(y - horizon > 100 * SUN_PEAK / 3, `the ridge is well under the horizon at ${x}`);
        assert.ok(y < 100, `the ridge is still inside the tile at ${x}`);
    }
    assert.ok(sunRidge(0, 200, 100) > sunRidge(20, 200, 100), "the ridge is at its lowest against the edge");
});

// Not free parameters: if the crossings are not sunrise and sunset the sun rises out of the
// ground and sets into the sky. SUN_SPREAD is solved from the others to hold this.
test("the ridge crosses the horizon exactly at sunrise and sunset", () => {
    const horizon = sunHorizon(100);
    for (const progress of [0, 1])
        near(sunMarker(200, 100, progress).y, horizon, `crossing at progress ${progress}`);
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

test("sunMarker is at its highest at solar noon", () => {
    near(sunMarker(200, 100, 0.5).y, sunHorizon(100) - 100 * SUN_PEAK, "noon is the peak");
});

test("sunTrack measures the daylight span from sunrise to sunset", () => {
    const sunrise = new Date(2026, 7, 2, 5, 30);
    const sunset = new Date(2026, 7, 2, 18, 30);

    near(sunTrack(new Date(2026, 7, 2, 5, 30), sunrise, sunset), 0, "sunrise");
    near(sunTrack(new Date(2026, 7, 2, 12, 0), sunrise, sunset), 0.5, "midday");
    near(sunTrack(new Date(2026, 7, 2, 18, 30), sunrise, sunset), 1, "sunset");
});

// Unclamped on purpose: a clamped fraction cannot tell sunset from an hour after it, and
// that difference is the whole of whether there is a sun to draw.
test("sunTrack runs past both ends rather than clamping to them", () => {
    const sunrise = new Date(2026, 7, 2, 5, 30);
    const sunset = new Date(2026, 7, 2, 18, 30);

    assert.ok(sunTrack(new Date(2026, 7, 2, 20, 0), sunrise, sunset) > 1, "after sunset");
    assert.ok(sunTrack(new Date(2026, 7, 2, 23, 59), sunrise, sunset) > 1, "late night");
    assert.ok(sunTrack(new Date(2026, 7, 2, 4, 0), sunrise, sunset) < 0, "before sunrise");
});

test("isDaylight holds from sunrise to sunset inclusive and nowhere else", () => {
    for (const progress of [0, 0.001, 0.5, 0.999, 1])
        assert.equal(isDaylight(progress), true, `daylight at ${progress}`);
    for (const progress of [-0.001, -0.4, 1.001, 1.4])
        assert.equal(isDaylight(progress), false, `night at ${progress}`);
});

test("sunTrack answers the start of the day for readings the service does not have", () => {
    const sunrise = new Date(2026, 7, 2, 5, 30);
    const sunset = new Date(2026, 7, 2, 18, 30);

    assert.equal(sunTrack(null, sunrise, sunset), 0);
    assert.equal(sunTrack(new Date(2026, 7, 2, 12, 0), null, sunset), 0);
    assert.equal(sunTrack(new Date(2026, 7, 2, 12, 0), sunrise, null), 0);
    assert.equal(sunTrack(new Date(2026, 7, 2, 12, 0), sunset, sunrise), 0);
});

// The sun is painted, not laid out, so the daylight span being inset far enough is the only
// thing keeping the disc off the frame. Checked at the real tile width, where the margin is
// tightest.
test("the whole disc fits inside the tile everywhere the sun is drawn", () => {
    const reach = sunMarkerReach();
    assert.ok(reach > SUN_MARKER_RADIUS, "the reach covers the scallop and the ring");

    for (const progress of [0, 0.25, 0.5, 0.75, 1]) {
        const marker = sunMarker(160, 107.67, progress);
        assert.ok(marker.x - reach > 0, `the disc clears the left edge at ${progress}`);
        assert.ok(marker.x + reach < 160, `the disc clears the right edge at ${progress}`);
    }
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
    // The ridge has to fall further below the horizon than it rises above it, or there is
    // nothing left of the curve to show through the ground.
    assert.ok(SUN_BASE > SUN_PEAK);
    assert.ok(SUN_HORIZON + SUN_BASE < 1, "the ridge settles inside the tile rather than under it");
    assert.ok(SUN_SPREAD > 0);
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
