import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const gauge = loadQmlJs(path.join(repoRoot, "modules", "dashboard", "storage_gauge.js"), ["START_ANGLE", "SWEEP", "TRACK_GAP", "occupancyArcs"]);

// These are pixel distances recovered from angles, so they arrive a rounding error out. The
// gauge is 128px across; anything this test could care about is far coarser than a
// thousandth of one.
function near(actual, expected, message) {
    assert.ok(Math.abs(actual - expected) < 1e-6, `${message ?? "value"}: ${actual} is not ${expected}`);
}

// Qt measures arcs clockwise from three o'clock, so 135° is the bottom left and 270° of it
// closes at the bottom right. The opening is under the reading rather than beside it: a
// gauge broken at one side reads as a shape pointing somewhere.
test("the gauge is 270° with its opening centred at the bottom", () => {
    assert.equal(gauge.START_ANGLE, 135);
    assert.equal(gauge.SWEEP, 270);
    assert.equal(gauge.START_ANGLE + gauge.SWEEP, 405);
});

test("occupancy is the fraction of the sweep the active arc covers", () => {
    assert.equal(gauge.occupancyArcs(0, 58, 8).activeSweep, 0);
    assert.equal(gauge.occupancyArcs(0.5, 58, 8).activeSweep, 135);
    assert.equal(gauge.occupancyArcs(1, 58, 8).activeSweep, 270);
});

// Material 3 breaks the track where the active indicator ends, so the two are one reading
// with a joint rather than one continuous ring in two colours.
test("the track resumes past a gap and ends where a full filesystem would", () => {
    const { activeSweep, trackStartAngle, trackSweep } = gauge.occupancyArcs(0.5, 58, 8);
    const separation = (trackStartAngle - gauge.START_ANGLE - activeSweep) / 180 * Math.PI * 58;

    near(separation, gauge.TRACK_GAP + 8, "the break the reader sees");
    assert.equal(trackStartAngle + trackSweep, gauge.START_ANGLE + gauge.SWEEP);
});

// The gap is the width of the break the reader sees, and a round cap puts half a stroke of
// paint past the end of its own arc at both sides of it. Separating the angles by the gap
// alone is what makes a 4px break disappear under a thick stroke.
test("the gap is left showing after both round caps have taken their half stroke", () => {
    const thin = gauge.occupancyArcs(0.5, 58, 4);
    const thick = gauge.occupancyArcs(0.5, 58, 16);
    const painted = arcs => (arcs.trackStartAngle - gauge.START_ANGLE - arcs.activeSweep) / 180 * Math.PI * 58;

    near(painted(thin) - 4, gauge.TRACK_GAP, "a thin stroke's break");
    near(painted(thick) - 16, gauge.TRACK_GAP, "a thick stroke's break");
});

// The gap is a distance on the ring, not an angle, so it stays the same width whatever the
// gauge is sized to.
test("a wider gauge spends fewer degrees on the same gap", () => {
    const small = gauge.occupancyArcs(0.5, 40, 8);
    const large = gauge.occupancyArcs(0.5, 80, 8);

    assert.ok(small.trackStartAngle > large.trackStartAngle);
    near(small.trackStartAngle - gauge.START_ANGLE - small.activeSweep,
        2 * (large.trackStartAngle - gauge.START_ANGLE - large.activeSweep), "the gap in degrees");
});

// The dot marks where a full filesystem would end. Once the arc has reached it there is
// nothing left for it to mark, and a track drawn backwards past it would be a lie.
test("a full filesystem leaves no track and no stop to mark", () => {
    const full = gauge.occupancyArcs(1, 58, 8);

    assert.equal(full.trackSweep, 0);
    assert.equal(full.stopVisible, false);
    assert.equal(gauge.occupancyArcs(0.5, 58, 8).stopVisible, true);
});

// The last percent of a filesystem is where the reading matters most, and an arc drawn past
// its own end would be the card's own rounding saying the disk was over-full.
test("occupancy at the very top of the scale stays inside the sweep", () => {
    const nearlyFull = gauge.occupancyArcs(0.995, 58, 8);

    assert.ok(nearlyFull.activeSweep < gauge.SWEEP);
    assert.equal(nearlyFull.trackSweep, 0);
    assert.ok(nearlyFull.trackStartAngle > gauge.START_ANGLE + gauge.SWEEP);
});

// Before the first `df` returns there is no reading, and a gauge is a shape that has to be
// drawn either way. Empty is the one position that cannot be mistaken for a measurement.
test("an unavailable or impossible occupancy draws as empty", () => {
    for (const fraction of [null, undefined, NaN, -0.2, "20%"])
        assert.equal(gauge.occupancyArcs(fraction, 58, 8).activeSweep, 0);

    assert.equal(gauge.occupancyArcs(1.4, 58, 8).activeSweep, 270);
});
