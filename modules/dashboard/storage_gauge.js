/**
 * The occupancy gauge's arc geometry, in the convention `PathAngleArc` uses: degrees
 * clockwise from three o'clock.
 *
 * A gauge rather than a ring, because a filesystem has an end. The opening is at the bottom,
 * under the reading, so the shape does not point anywhere.
 */

.pragma library

const START_ANGLE = 135;
const SWEEP = 270;

// Material 3 breaks the track where the active indicator ends, so the pair reads as one
// reading with a joint in it rather than as a ring in two colours. This is the width of that
// break on the ring, in pixels — an angle would widen the break on a larger gauge.
const TRACK_GAP = 4;

/**
 * `fraction` is 0–1 occupancy, or anything else when there is no reading — an unread
 * filesystem draws empty, which is the one position that cannot be read as a measurement.
 * `radius` is the arc's own radius, the gauge's outer radius less half its stroke.
 */
function occupancyArcs(fraction, radius) {
    const occupancy = typeof fraction === "number" && Number.isFinite(fraction)
        ? Math.min(Math.max(fraction, 0), 1)
        : 0;

    const gapDegrees = radius > 0 ? TRACK_GAP / radius * 180 / Math.PI : 0;
    const activeSweep = SWEEP * occupancy;
    const trackStartAngle = START_ANGLE + activeSweep + gapDegrees;
    const trackSweep = Math.max(START_ANGLE + SWEEP - trackStartAngle, 0);

    return {
        activeSweep: activeSweep,
        trackStartAngle: trackStartAngle,
        trackSweep: trackSweep,
        // The dot marks where a full filesystem would end, so it has nothing left to say
        // once the arc has arrived there.
        stopVisible: trackSweep > 0
    };
}
