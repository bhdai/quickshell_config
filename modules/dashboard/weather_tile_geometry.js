/**
 * The two weather tiles whose shape is the reading rather than a decoration beside it: the
 * humidity tile's waterline and the sun tile's daylight arc.
 *
 * Both answer plain point lists in a box measured from its top-left, which is what Canvas
 * and Shape both want, and which is why none of this needs a running QML engine to check.
 * Nothing here clamps to the box for the caller — the humidity crest is allowed to run past
 * the top edge at a full reading, and the Canvas that draws it clips.
 */

.pragma library

// The wave motif's parameters follow Material 3's wavy progress indicator, which is the one
// place Google publishes numbers for it: a wavelength in pixels and an amplitude, both fixed
// rather than scaled to the tile, so every tile that grows a wave keeps the same water.
// Unlike that indicator the phase here is a constant — this wave reports a humidity, not a
// job in progress, so animating it would claim motion the reading does not have. The offset
// keeps a zero crossing rather than a crest against the tile's left edge.
const WAVE_WAVELENGTH = 44;
const WAVE_AMPLITUDE = 3.5;
const WAVE_PHASE = Math.PI;
const WAVE_SAMPLES = 40;

// The sun tile is a landscape rather than a chart: the horizon cuts the whole tile in two,
// the hill passes under it at both edges instead of landing on it, and the times sit on the
// ground below. All of it is a fraction of the tile so the composition survives a resize.
//
// The ridge is a bell, not the half sine solar elevation actually follows: flat tails and a
// broad crown read as terrain at 100px wide, where a sine reads as a graph of something.
// SUN_TAIL is how far the ground settles below the horizon once the bell has died away.
// Tuned against the 160x108 the dashboard's 2x3 grid actually gives a tile, where the header
// row and the two clock times leave about 35px of sky and 45px of ground. A horizon lower
// than this puts the sunrise time on the line it is supposed to be standing under.
const SUN_HORIZON = 0.53;
const SUN_PEAK = 0.17;
const SUN_TAIL = 0.025;
const SUN_SPREAD = 0.22;
const SUN_SAMPLES = 40;

// Daylight is inset from both edges, so the tile carries a little night either side of it
// and the ridge crosses the horizon at sunrise and sunset rather than at the tile's corners.
const SUN_DAY_SPAN = 0.86;

// Material 3's Sunny shape, near enough at this size: a circle rippled by a whole number of
// lobes. SUN_MARKER_SAMPLES is a multiple of twice the lobe count so the sampling lands on
// every crest and every valley, and closes without a seam.
const SUN_MARKER_RADIUS = 6.5;
const SUN_MARKER_LOBES = 10;
const SUN_MARKER_SCALLOP = 0.08;
const SUN_MARKER_SAMPLES = 60;

function waterLevel(humidity) {
    if (typeof humidity !== "number" || !isFinite(humidity))
        return 0;
    return Math.max(0, Math.min(1, humidity / 100));
}

/**
 * The top edge of the filled water, left to right, for a box `width` by `height`. `level` is
 * a 0..1 fill fraction measured up from the bottom, so the caller closes the region by
 * running down to the two bottom corners.
 */
function waveLine(width, height, level, amplitude, wavelength, phase, samples) {
    const baseline = height * (1 - level);
    const points = [];
    for (let i = 0; i <= samples; i++) {
        const x = width * i / samples;
        points.push({
            x: x,
            y: baseline + amplitude * Math.sin(2 * Math.PI * x / wavelength + phase)
        });
    }
    return points;
}

function sunHorizon(height) {
    return height * SUN_HORIZON;
}

// The skyline at a given x. Symmetric about the middle of the tile, which is solar noon.
function sunRidge(x, width, height) {
    const offset = x / width - 0.5;
    const bell = Math.exp(-(offset * offset) / (2 * SUN_SPREAD * SUN_SPREAD));
    return height * (SUN_HORIZON + SUN_TAIL - (SUN_PEAK + SUN_TAIL) * bell);
}

// The skyline sampled left to right. The caller closes it against the bottom of the tile.
function sunPath(width, height, samples) {
    const points = [];
    for (let i = 0; i <= samples; i++) {
        const x = width * i / samples;
        points.push({ x: x, y: sunRidge(x, width, height) });
    }
    return points;
}

// Where the sun sits on that skyline. `progress` is weather_format.js's dayProgress(),
// already clamped, so a reading taken at night parks the sun where the ridge crosses the
// horizon rather than running it off the end.
function sunMarker(width, height, progress) {
    const x = width * ((1 - SUN_DAY_SPAN) / 2 + progress * SUN_DAY_SPAN);
    return { x: x, y: sunRidge(x, width, height) };
}

/**
 * A circle whose radius ripples between `radius * (1 ± scallop)` once per lobe. Returns the
 * ring without repeating the first point, so the caller closes the path itself.
 */
function scallopedCircle(cx, cy, radius, lobes, scallop, samples) {
    const points = [];
    for (let i = 0; i < samples; i++) {
        const angle = 2 * Math.PI * i / samples;
        const r = radius * (1 + scallop * Math.cos(lobes * angle));
        points.push({ x: cx + r * Math.cos(angle), y: cy + r * Math.sin(angle) });
    }
    return points;
}
