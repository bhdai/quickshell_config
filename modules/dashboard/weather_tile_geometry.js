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

// The wave motif is Material 3's wavy progress indicator, and the amplitude is the number
// Google publishes for it. The wavelength is not, and cannot be: the water spans the tile
// edge to edge, so a length that does not divide the tile leaves one edge mid-crest and the
// other mid-trough, and the eye reads a waterline that slopes. The wave is therefore counted
// rather than measured, which closes it at both edges on a tile of any width.
//
// WAVE_COUNT has to stay a half-integer — three and a half, four and a half — and that is
// the whole of why this looks right. A whole number of waves does close at the edges, but it
// makes the line point-symmetric: the crest sitting a few pixels in from the left edge is
// answered by a trough the same distance from the right. Half a wave more mirrors it about
// the tile's centre instead, so the two edges are the same height and the two ends the same
// shape. That matters most at a high reading, where the waterline rides up behind the header
// text and those two ends are the only part of the wave still visible.
//
// M3's published 44px was set against a tile 160 wide, where it fell close to three and a
// half waves; three and a half across the square 108 tile is 31px, near enough to the same
// water. WAVE_AMPLITUDE is the one to move for deeper crests, and is still fixed in pixels
// because depth is not what has to meet at the edges.
//
// Unlike that indicator the phase here is a constant — this wave reports a humidity, not a
// job in progress, so animating it would claim motion the reading does not have. At this
// phase both edges sit on the waterline itself rather than on a crest, so the water meets
// the tile's sides flat.
//
// The line is drawn as straight segments between samples, and seventeen points per wave is
// what the crests need to not read as folded paper.
const WAVE_COUNT = 3.5;
const WAVE_AMPLITUDE = 3.5;
const WAVE_PHASE = Math.PI;
const WAVE_SAMPLES = 60;

// The wavelength for a box of this width. The caller passes it to waveLine(), which stays
// unaware of the tile so it can be checked against arbitrary geometry.
function waveWavelength(width) {
    return width / WAVE_COUNT;
}

// The sun tile is a landscape rather than a chart: the horizon cuts the whole tile in two,
// the hill passes under it at both edges instead of landing on it, and the times sit on the
// ground below. All of it is a fraction of the tile so the composition survives a resize.
//
// The ridge is a bell, not the half sine solar elevation actually follows: flat tails and a
// broad crown read as terrain at 100px wide, where a sine reads as a graph of something.
// SUN_BASE is how far the ground settles below the horizon once the bell has died away.
// Tuned against the 108x108 the dashboard's 2x3 grid actually gives a tile, where the header
// row and the two clock times leave about 35px of sky and 45px of ground. A horizon lower
// than this puts the sunrise time on the line it is supposed to be standing under.
//
// Both of the other two are what make the flanks steep, and they are what to move to make
// them steeper still — SUN_SPREAD is solved from them and cannot be set directly. The hill
// standing higher and its tails falling deeper both narrow the bell, and the sky above the
// crest is the binding limit: at this peak it is within a pixel of the header row, so any
// more rise has to come out of SUN_HORIZON, which has about a pixel of its own before the
// horizon reaches the clock times.
//
// SUN_BASE stays deeper than SUN_PEAK: the ridge has to keep falling well under the horizon
// and stay inside the tile, so the ground can be a translucent layer with the curve still
// visibly descending behind it rather than an opaque block the curve stops against.
const SUN_HORIZON = 0.53;
const SUN_PEAK = 0.2;
const SUN_BASE = 0.34;
const SUN_SAMPLES = 40;

// Daylight is inset from both edges, so the tile carries a little night either side of it.
const SUN_DAY_SPAN = 0.75;

// Not a free parameter. Sunrise and sunset have to be the two points where the ridge crosses
// the horizon, or the sun rises out of the ground and sets into the sky; this is
// sunRidge(sunrise) === sunHorizon() solved for the width of the bell.
const SUN_SPREAD = Math.sqrt(-(SUN_DAY_SPAN / 2) * (SUN_DAY_SPAN / 2) / (2 * Math.log(SUN_BASE / (SUN_PEAK + SUN_BASE))));

// The stroke that separates the sun from whatever it is sitting on, as a radius rather than
// a width, because only the outer half of it is drawn outside the disc.
const SUN_MARKER_RING = 1.5;

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
    return height * (SUN_HORIZON + SUN_BASE - (SUN_PEAK + SUN_BASE) * bell);
}

/**
 * Where `now` sits in the daylight span: 0 at sunrise, 1 at sunset. Deliberately not clamped
 * — outside that range is night, which is the one thing a clamped fraction cannot say, and
 * isDaylight() is the test callers gate on. A reading the service does not have yet, or a
 * sunset before its sunrise, answers 0.
 */
function sunTrack(now, sunrise, sunset) {
    if (!now || !sunrise || !sunset)
        return 0;
    const span = sunset.getTime() - sunrise.getTime();
    if (!isFinite(span) || span <= 0)
        return 0;
    return (now.getTime() - sunrise.getTime()) / span;
}

// Whether a sunTrack() position is one the sun is actually up for. Sunrise and sunset
// themselves count: they are the moments the sun is on the horizon, not past it.
function isDaylight(progress) {
    return progress >= 0 && progress <= 1;
}

// How far out the sun's disc reaches from its centre, ring included.
function sunMarkerReach() {
    return SUN_MARKER_RADIUS * (1 + SUN_MARKER_SCALLOP) + SUN_MARKER_RING;
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

// Where the sun sits on that skyline, given a sunTrack() position. Only meaningful while
// isDaylight() holds; the daylight span is inset far enough that the whole disc fits.
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
