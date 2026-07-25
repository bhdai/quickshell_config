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

test("pressing an edge button puts the whole growth on its single neighbour", () => {
    assert.deepEqual(
        allocateWidths(visible(6), 350, 10, 0, 8),
        [58, 42, 50, 50, 50, 50],
    );
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
        [58, 0, 42, 50],
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
