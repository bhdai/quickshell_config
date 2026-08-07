import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const model = loadQmlJs(path.join(repoRoot, "modules", "bar", "WorkspaceModel.js"), [
    "MIN_SLOTS",
    "MAX_SLOTS",
    "workspaceModel",
    "pillGeometry",
    "focusCommand"
]);

const { MIN_SLOTS, MAX_SLOTS, workspaceModel, pillGeometry, focusCommand } = model;

// #120's chosen tokens, as WorkspaceIndicator.qml passes them in.
const tokens = { dotWidth: 18, spacing: 3, padding: 10, pillWidth: 22 };
const stride = tokens.dotWidth + tokens.spacing;

function workspace(id, extra) {
    return Object.assign({ id: id, name: String(id), windowCount: 1, urgent: false }, extra);
}

function ids(slots) {
    return slots.map(slot => slot.id);
}

test("the row bottoms out at five slots with nothing to show", () => {
    const result = workspaceModel({ workspaces: [], activeId: 0, specialName: "" });
    assert.equal(result.slots.length, MIN_SLOTS);
    assert.deepEqual(ids(result.slots), [1, 2, 3, 4, 5]);
    assert.equal(result.activeIndex, -1);
    assert.deepEqual(result.slots.map(slot => slot.occupied), [false, false, false, false, false]);
});

test("an active workspace missing from the list has nowhere to point", () => {
    const result = workspaceModel({ workspaces: [workspace(1), workspace(2)], activeId: 5, specialName: "" });
    assert.equal(result.slots.length, 5);
    assert.equal(result.activeIndex, -1);
});

test("an active workspace above the ceiling has nowhere to point", () => {
    const result = workspaceModel({
        workspaces: [workspace(1), workspace(12)],
        activeId: 12,
        specialName: ""
    });
    assert.equal(result.slots.length, MAX_SLOTS);
    assert.equal(result.activeIndex, -1);
});

test("the active workspace picks its own slot", () => {
    const result = workspaceModel({
        workspaces: [workspace(1), workspace(2), workspace(3)],
        activeId: 3,
        specialName: ""
    });
    assert.equal(result.activeIndex, 2);
});

test("the count follows the highest workspace present, clamped both ends", () => {
    const counts = [1, 4, 5, 6, 10, 12].map(highest =>
        workspaceModel({ workspaces: [workspace(highest)], activeId: 0, specialName: "" }).slots.length
    );
    assert.deepEqual(counts, [5, 5, 5, 6, 10, 10]);
});

test("the active workspace can grow the row past the highest one present", () => {
    const result = workspaceModel({ workspaces: [workspace(1)], activeId: 8, specialName: "" });
    assert.equal(result.slots.length, 8);
});

test("negative-id specials never become slots", () => {
    const result = workspaceModel({
        workspaces: [workspace(-99, { name: "special:quake" }), workspace(1)],
        activeId: 1,
        specialName: ""
    });
    assert.deepEqual(ids(result.slots), [1, 2, 3, 4, 5]);
    assert.equal(result.activeIndex, 0);
});

test("a gap in the workspaces still yields a contiguous row", () => {
    const result = workspaceModel({ workspaces: [workspace(1), workspace(7)], activeId: 1, specialName: "" });
    assert.deepEqual(ids(result.slots), [1, 2, 3, 4, 5, 6, 7]);
    assert.deepEqual(result.slots.map(slot => slot.occupied), [true, false, false, false, false, false, true]);
});

test("a workspace that exists but holds nothing is not occupied", () => {
    const result = workspaceModel({
        workspaces: [workspace(1, { windowCount: 0 })],
        activeId: 1,
        specialName: ""
    });
    assert.equal(result.slots[0].occupied, false);
});

test("urgent lands on the slot that went urgent", () => {
    const result = workspaceModel({
        workspaces: [workspace(1), workspace(3, { urgent: true })],
        activeId: 1,
        specialName: ""
    });
    assert.deepEqual(result.slots.map(slot => slot.urgent), [false, false, true, false, false]);
});

test("an urgent workspace above the ceiling is dropped with the rest of it", () => {
    const result = workspaceModel({
        workspaces: [workspace(1), workspace(11, { urgent: true })],
        activeId: 1,
        specialName: ""
    });
    assert.equal(result.slots.length, MAX_SLOTS);
    assert.deepEqual(result.slots.filter(slot => slot.urgent), []);
});

test("the special is the one the event named, not a same-id decoy in the list", () => {
    const result = workspaceModel({
        workspaces: [workspace(-99, { name: "special:quake" }), workspace(1)],
        activeId: 1,
        specialName: "special"
    });
    assert.deepEqual(result.special, { name: "special", visible: true });
});

test("an empty specialName beats a special still sitting in the list", () => {
    const result = workspaceModel({
        workspaces: [workspace(-99, { name: "special:quake" }), workspace(1)],
        activeId: 1,
        specialName: ""
    });
    assert.deepEqual(result.special, { name: "", visible: false });
});

test("the workspaces handed in come back untouched", () => {
    const workspaces = [workspace(3), workspace(1), workspace(-99, { name: "special" })];
    const before = JSON.parse(JSON.stringify(workspaces));
    workspaceModel({ workspaces: workspaces, activeId: 3, specialName: "special" });
    assert.deepEqual(workspaces, before);
});

test("the stride between slots is the same at every count", () => {
    for (let count = MIN_SLOTS; count <= MAX_SLOTS; ++count) {
        const positions = [];
        for (let i = 0; i < count; ++i)
            positions.push(pillGeometry({ count: count, activeIndex: i }, tokens).pillX);

        for (let i = 1; i < count; ++i)
            assert.equal(positions[i] - positions[i - 1], stride, `count ${count}, slot ${i}`);
    }
});

test("the pill is centred on its slot", () => {
    const count = MAX_SLOTS;
    for (let i = 0; i < count; ++i) {
        const { pillX } = pillGeometry({ count: count, activeIndex: i }, tokens);
        const slotCentre = tokens.padding + i * stride + tokens.dotWidth / 2;
        assert.equal(pillX + tokens.pillWidth / 2, slotCentre, `slot ${i}`);
    }
});

test("the widget is 122, 185 and 227 wide at five, eight and ten slots", () => {
    const widths = [5, 8, 10].map(count => pillGeometry({ count: count, activeIndex: 0 }, tokens).contentWidth);
    assert.deepEqual(widths, [122, 185, 227]);
});

test("nowhere to point parks the pill at zero rather than throwing", () => {
    const geometry = pillGeometry({ count: MIN_SLOTS, activeIndex: -1 }, tokens);
    assert.equal(geometry.pillX, 0);
    assert.equal(geometry.contentWidth, 122);
});

test("focusCommand emits the Lua dispatch form", () => {
    assert.equal(focusCommand(3), "hl.dsp.focus({ workspace = 3 })");
    assert.equal(focusCommand(10), "hl.dsp.focus({ workspace = 10 })");
});
