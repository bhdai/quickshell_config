import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { pickBatterySymbol } = loadQmlJs(
    new URL("../services/BatteryFormat.js", import.meta.url),
    ["pickBatterySymbol"],
);

test("charging has one symbol of its own regardless of level", () => {
    assert.equal(pickBatterySymbol({ percentage: 0.02, charging: true }), "battery_charging_full");
    assert.equal(pickBatterySymbol({ percentage: 0.9, charging: true }), "battery_charging_full");
});

test("a full battery uses the full symbol", () => {
    assert.equal(pickBatterySymbol({ percentage: 1, charging: false }), "battery_full");
});

test("an empty battery uses the zero-bar symbol", () => {
    assert.equal(pickBatterySymbol({ percentage: 0, charging: false }), "battery_0_bar");
});

test("intermediate levels map onto the bar steps between them", () => {
    assert.equal(pickBatterySymbol({ percentage: 0.5, charging: false }), "battery_4_bar");
    assert.equal(pickBatterySymbol({ percentage: 0.25, charging: false }), "battery_2_bar");
    assert.equal(pickBatterySymbol({ percentage: 0.75, charging: false }), "battery_5_bar");
});

// UPower reports a fraction, but a device that has just appeared can report nonsense, and
// a symbol name with a bar count outside 0-6 renders as a blank glyph rather than an icon.
test("a level outside zero to one is clamped rather than producing a missing glyph", () => {
    assert.equal(pickBatterySymbol({ percentage: 1.4, charging: false }), "battery_full");
    assert.equal(pickBatterySymbol({ percentage: -0.2, charging: false }), "battery_0_bar");
});

test("an absent level reports the zero-bar symbol rather than a broken name", () => {
    assert.equal(pickBatterySymbol({ percentage: undefined, charging: false }), "battery_0_bar");
});
