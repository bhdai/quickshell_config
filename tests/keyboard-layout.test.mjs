import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { activeLayout } = loadQmlJs(
    new URL("../services/KeyboardLayoutParse.js", import.meta.url),
    ["activeLayout"],
);

function devices(keyboards) {
    return JSON.stringify({ mice: [], keyboards, tablets: [], touch: [], switches: [] });
}

function keyboard(overrides) {
    return Object.assign({
        address: "0x0",
        name: "at-translated-set-2-keyboard",
        rules: "",
        model: "",
        layout: "us",
        variant: "",
        options: "",
        active_layout_index: 0,
        active_keymap: "English (US)",
        capsLock: false,
        numLock: false,
        main: true,
    }, overrides);
}

test("a single-layout main keyboard reports its code", () => {
    assert.equal(activeLayout(devices([keyboard({})])), "us");
});

// Every keyboard carries the same configured layout list, and Hyprland routes input to the
// one it marks `main` — the power button and the video bus are keyboards too.
test("the main keyboard wins over the others listed before it", () => {
    const json = devices([
        keyboard({ name: "power-button", layout: "de", main: false }),
        keyboard({ name: "at-translated-set-2-keyboard", layout: "us", main: true }),
    ]);

    assert.equal(activeLayout(json), "us");
});

test("with no keyboard marked main the first one answers", () => {
    const json = devices([
        keyboard({ name: "video-bus", layout: "fr", main: false }),
        keyboard({ name: "power-button", layout: "de", main: false }),
    ]);

    assert.equal(activeLayout(json), "fr");
});

// The list is what is *configured*; the index is what is in effect. Reading the list alone
// would report `us` on a machine sitting on its second layout.
test("the active index picks the layout in effect out of the configured list", () => {
    const json = devices([keyboard({ layout: "us,de,fr", active_layout_index: 1 })]);

    assert.equal(activeLayout(json), "de");
});

test("an index past the end of the list falls back to the first layout", () => {
    const json = devices([keyboard({ layout: "us,de", active_layout_index: 5 })]);

    assert.equal(activeLayout(json), "us");
});

test("a comma-separated list with spaces is trimmed", () => {
    const json = devices([keyboard({ layout: "us, de", active_layout_index: 1 })]);

    assert.equal(activeLayout(json), "de");
});

// Nothing here may throw: this runs on the lock screen, where an exception would be an
// error in a surface the user cannot dismiss.
test("output that is not JSON reports no layout", () => {
    assert.equal(activeLayout("hyprctl: command not found"), "");
});

test("empty output reports no layout", () => {
    assert.equal(activeLayout(""), "");
});

test("a device list with no keyboards reports no layout", () => {
    assert.equal(activeLayout(devices([])), "");
});

test("a keyboard with no layout configured reports no layout", () => {
    assert.equal(activeLayout(devices([keyboard({ layout: "" })])), "");
});
