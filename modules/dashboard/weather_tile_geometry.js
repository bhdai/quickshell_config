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
const WAVE_AMPLITUDE = 2.5;
const WAVE_PHASE = Math.PI;
const WAVE_SAMPLES = 40;

const SUN_SAMPLES = 40;

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

/**
 * The sun's track across the box: the horizon is the bottom edge, the peak is solar noon at
 * the top of the box, and the shape between them is the half sine that solar elevation
 * roughly follows. The horizontal axis is the sunrise-to-sunset span, not clock time, so the
 * curve is symmetric by construction.
 */
function sunPath(width, height, samples) {
    const points = [];
    for (let i = 0; i <= samples; i++)
        points.push(sunMarker(width, height, i / samples));
    return points;
}

// Where the sun sits on that track. `progress` is weather_format.js's dayProgress(), already
// clamped, so a reading taken at night parks the marker on the horizon at one end.
function sunMarker(width, height, progress) {
    return {
        x: width * progress,
        y: height * (1 - Math.sin(Math.PI * progress))
    };
}
