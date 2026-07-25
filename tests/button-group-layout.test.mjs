import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { allocateWidths } = loadQmlJs(
    new URL("../modules/common/widgets/ButtonGroupLayout.js", import.meta.url),
    ["allocateWidths"],
);

const visible = count => Array.from({ length: count }, () => true);

function rowWidth(widths, visibility, spacing) {
    const shown = widths.filter((_, i) => visibility[i]);
    return shown.reduce((sum, width) => sum + width, 0) + spacing * (shown.length - 1);
}

// Where each visible button's left edge lands once the row is packed, which is what the eye
// actually reads: a button whose edge moves has visibly shifted even if its width held.
function leftEdges(widths, visibility, spacing) {
    const edges = [];
    let edge = 0;
    for (let i = 0; i < widths.length; ++i) {
        if (!visibility[i])
            continue;
        edges.push(edge);
        edge += widths[i] + spacing;
    }
    return edges;
}

test("buttons share the row equally when nothing is pressed", () => {
    assert.deepEqual(
        allocateWidths(visible(6), 350, 10, -1, 8),
        [50, 50, 50, 50, 50, 50],
    );
});

test("pressing a button shrinks only its two neighbours", () => {
    assert.deepEqual(
        allocateWidths(visible(6), 350, 10, 2, 8),
        [50, 46, 58, 46, 50, 50],
    );
});

// Growth is per side, so an edge button — which has only one side to borrow from — grows
// half as much rather than taking a double helping out of its one neighbour.
test("pressing an edge button borrows from its one side only", () => {
    assert.deepEqual(
        allocateWidths(visible(6), 350, 10, 0, 8),
        [54, 46, 50, 50, 50, 50],
    );
});

test("an edge button's neighbour gives up exactly what a middle button's does", () => {
    const edge = allocateWidths(visible(6), 350, 10, 0, 8);
    const middle = allocateWidths(visible(6), 350, 10, 2, 8);

    assert.equal(edge[1], middle[1]);
    assert.equal(edge[1], middle[3]);
});

test("the row width is unchanged by a press", () => {
    const visibility = visible(6);
    const resting = allocateWidths(visibility, 350, 10, -1, 8);

    for (let pressed = 0; pressed < visibility.length; ++pressed) {
        assert.equal(
            rowWidth(allocateWidths(visibility, 350, 10, pressed, 8), visibility, 10),
            rowWidth(resting, visibility, 10),
        );
    }
});

test("hidden slots get no width and are skipped when finding neighbours", () => {
    assert.deepEqual(
        allocateWidths([true, false, true, true], 170, 10, 0, 8),
        [54, 0, 46, 50],
    );
});

test("a neighbour never shrinks past half its resting width", () => {
    assert.deepEqual(allocateWidths(visible(2), 110, 10, 0, 200), [75, 25]);
});

test("a lone button keeps the whole row on press", () => {
    assert.deepEqual(allocateWidths([true], 50, 10, 0, 8), [50]);
});

test("a press on a hidden slot leaves the row at rest", () => {
    assert.deepEqual(
        allocateWidths([true, false, true], 110, 10, 1, 8),
        [50, 0, 50],
    );
});

test("a row with nothing visible allocates nothing", () => {
    assert.deepEqual(allocateWidths([false, false], 350, 10, -1, 8), [0, 0]);
});

test("widths are whole pixels even when the row does not divide evenly", () => {
    const widths = allocateWidths(visible(6), 383, 10, 2, 8);

    assert.deepEqual(widths.map(Math.round), widths);
    assert.equal(rowWidth(widths, visible(6), 10), 383);
});

// The regression: Qt rounds each item's width to whole pixels on its own, so three
// independently rounded animating tiles used to drift the whole right-hand side of the row
// outward by a pixel or two part-way through the press. Growth arrives here already scaled
// by the animation's progress, overshoot included, so every frame has to hold the line.
test("buttons past the pressed tile's neighbours never move, at any point in the press", () => {
    const visibility = visible(6);
    const resting = leftEdges(allocateWidths(visibility, 383, 10, -1, 8), visibility, 10);

    for (let progress = 0; progress <= 1.2; progress += 0.01) {
        const edges = leftEdges(allocateWidths(visibility, 383, 10, 2, 8 * progress), visibility, 10);

        assert.equal(edges[0], resting[0], `slot 0 moved at progress ${progress}`);
        assert.equal(edges[4], resting[4], `slot 4 moved at progress ${progress}`);
        assert.equal(edges[5], resting[5], `slot 5 moved at progress ${progress}`);
    }
});

test("the row never overflows its container mid-press", () => {
    const visibility = visible(6);

    for (let progress = 0; progress <= 1.2; progress += 0.01) {
        for (let pressed = 0; pressed < visibility.length; ++pressed) {
            const widths = allocateWidths(visibility, 383, 10, pressed, 8 * progress);
            assert.equal(rowWidth(widths, visibility, 10), 383);
        }
    }
});
