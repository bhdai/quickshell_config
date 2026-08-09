import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const ceiling = loadQmlJs(path.join(repoRoot, "modules", "dashboard", "network_ceiling.js"), [
    "FLOOR_BYTES_PER_SECOND",
    "ceilingTarget",
    "settleCeiling"
]);

const { FLOOR_BYTES_PER_SECOND, ceilingTarget, settleCeiling } = ceiling;

// An idle minute has no maximum to scale to, and a plot scaled to zero cannot be drawn at
// all. The floor is what turns silence into a flat line along the bottom of a 1 KiB/s plot
// rather than into a division by zero or a full-scale rendering of nothing.
test("an idle network scales to the floor rather than to its own zero", () => {
    assert.equal(FLOOR_BYTES_PER_SECOND, 1024);
    assert.equal(ceilingTarget([], []), 1024);
    assert.equal(ceilingTarget([0, 0, 0], [0, 0, 0]), 1024);
    assert.equal(ceilingTarget([12, 4], [7]), 1024);
});

// Two lines on two scales could not be compared: upload at a tenth of download would draw
// the same height, and the card would say the machine is sending as much as it receives.
test("the ceiling is the peak of both directions together", () => {
    assert.equal(ceilingTarget([5000, 20000], [3000]), 20000);
    assert.equal(ceilingTarget([5000], [3000, 90000]), 90000);
});

// A direction that is rebaselining puts NaN in its row. Treating that as a reading would
// scale the plot to a gap.
test("a missing reading is not a peak", () => {
    assert.equal(ceilingTarget([NaN, 4096, NaN], [NaN]), 4096);
    assert.equal(ceilingTarget([NaN], [NaN]), 1024);
});

// The ceiling has to reach a burst on the sample it arrives, because a line above the
// ceiling is drawn clamped to it: a lagging rise would flatten the top off exactly the spike
// the reader opened the card to see.
test("the ceiling rises to a burst immediately", () => {
    assert.equal(settleCeiling(1024, 500000), 500000);
    assert.equal(settleCeiling(NaN, 8192), 8192);
});

// Falling is the other way round. A peak leaving the window would otherwise drop the ceiling
// in one step and lift the whole line, which looks exactly like traffic that did not happen.
test("the ceiling falls by half its excess a sample, and settles", () => {
    assert.equal(settleCeiling(500000, 100000), 300000);
    assert.equal(settleCeiling(300000, 100000), 200000);

    // Close enough that another halving would be an invisible move on the plot and a
    // ceiling label that kept changing without meaning anything.
    assert.equal(settleCeiling(100500, 100000), 100000);
});

test("the settled ceiling never goes under the floor", () => {
    assert.equal(settleCeiling(2048, 1024), 1536);
    assert.equal(settleCeiling(1024, 1024), 1024);
});
