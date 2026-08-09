/**
 * The vertical scale the two network series share, and how it is allowed to move.
 *
 * Throughput has no ceiling to plot against: a link's capacity is not something this shell
 * can measure, so the scale has to come from the traffic itself. That makes the scale a way
 * for the card to mislead — a rescale and a change in traffic draw the same movement — which
 * is why the ceiling this produces is stated on the plot rather than left implicit, and why
 * it is damped instead of tracking the ring's maximum sample for sample.
 */

.pragma library

// An idle minute peaks at zero, and a plot cannot be drawn against a scale of zero. One
// KiB/s is small enough that real traffic immediately leaves it behind, so the floor only
// ever describes a network that is doing nothing.
const FLOOR_BYTES_PER_SECOND = 1024;

// How much of the distance to a lower target the ceiling gives up per sample. Halving is
// slow enough to read as one movement and short enough that a spike does not hold the plot
// squashed long after it has left the window.
const FALL_FRACTION = 0.5;

// Below this, another step would move the plot by less than it costs the reader to notice
// the ceiling label change again.
const SETTLE_FRACTION = 0.01;

// The fastest reading in one direction's window, or null if the window holds no reading at
// all. Non-finite entries are gaps rather than readings: a direction that spent the minute
// rebaselining has no peak, which a zero would misreport as a minute of silence.
function peakRate(values) {
    let peak = null;
    for (const value of values)
        if (Number.isFinite(value) && (peak === null || value > peak))
            peak = value;
    return peak;
}

// The scale both directions would need right now: whichever of them peaked higher, never
// under the floor.
function ceilingTarget(downloadPeak, uploadPeak) {
    let target = FLOOR_BYTES_PER_SECOND;
    for (const peak of [downloadPeak, uploadPeak])
        if (Number.isFinite(peak) && peak > target)
            target = peak;
    return target;
}

// Where the ceiling goes next, given where it is. Deliberately asymmetric: it reaches a
// burst on the sample the burst arrives, because a reading over the ceiling is drawn clamped
// to it and a lagging rise would flatten the top off the spike. It comes back down gradually,
// because a peak leaving the window would otherwise lift every line on the plot in one step —
// which is the movement traffic that stopped would make.
function settleCeiling(previous, target) {
    if (!Number.isFinite(previous) || target >= previous)
        return target;

    const next = target + (previous - target) * FALL_FRACTION;
    return next - target <= target * SETTLE_FRACTION ? target : next;
}
