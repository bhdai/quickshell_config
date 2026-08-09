/**
 * Where a history ring's samples land inside a plot box measured from its top-left, and
 * where the line has to break because there was no reading.
 *
 * The whole plot is this arithmetic plus a stroke, so it is checked without a running QML
 * engine. Nothing here knows what a sample means: the vertical scale arrives from the
 * caller, because only the caller knows whether its metric has a ceiling.
 */

.pragma library

// A line needs two points. Below this the plot draws nothing at all and the card says it is
// still collecting — an invented shape through one reading would be the one thing a history
// plot must never do.
const MIN_SAMPLES = 2;

// The x window is the ring's whole capacity, not the samples collected so far. One second is
// therefore the same distance whether the ring holds three rows or sixty, and a filling plot
// grows in from the right instead of stretching what it has across a minute it does not have.
function sampleX(index, count, capacity, width) {
    const stride = width / (capacity - 1);
    return width - (count - 1 - index) * stride;
}

function sampleY(value, maximum, height) {
    const fraction = maximum > 0 ? value / maximum : 0;
    return height - Math.min(Math.max(fraction, 0), 1) * height;
}

// The runs of consecutive readings in `values`, each as a point list. A non-finite sample is
// a gap and ends the run it interrupts; a run left one point long is dropped, having no line.
function seriesSegments(values, maximum, capacity, width, height) {
    const segments = [];
    let run = [];

    const closeRun = () => {
        if (run.length >= MIN_SAMPLES)
            segments.push(run);
        run = [];
    };

    for (let index = 0; index < values.length; index++) {
        const value = values[index];
        if (!Number.isFinite(value)) {
            closeRun();
            continue;
        }
        run.push({
            x: sampleX(index, values.length, capacity, width),
            y: sampleY(value, maximum, height)
        });
    }
    closeRun();

    return segments;
}

// The filled shape under one segment: the segment itself, dropped to the baseline at both
// ends. The first point is repeated at the baseline rather than a new left edge being
// invented, so the fill starts where the line starts even when the line starts mid-plot.
function areaPolygon(segment, height) {
    const first = segment[0];
    const last = segment[segment.length - 1];
    return [{ x: first.x, y: height }, ...segment, { x: last.x, y: height }];
}
