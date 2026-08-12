import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { Glyph, pickGlyph, usesChargingFill, nobFilled } = loadQmlJs(
    new URL("../services/battery_glyph.js", import.meta.url),
    ["Glyph", "pickGlyph", "usesChargingFill", "nobFilled"],
);

const discharging = { isCharging: false, isPluggedIn: false, percentage: 0.42 };
const charging = { isCharging: true, isPluggedIn: true, percentage: 0.42 };
// The state this machine sits in almost always: docked, at the 70% stop threshold.
const held = { isCharging: false, isPluggedIn: true, percentage: 0.69 };

test("on battery draws the nob", () => {
    assert.equal(pickGlyph(discharging), Glyph.Nob);
});

test("charging draws the bolt", () => {
    assert.equal(pickGlyph(charging), Glyph.Bolt);
});

// The bolt means current is moving. Held at the threshold nothing is, so the body keeps its
// own nob and lets the fill colour carry "on wall power" — the state this machine is in almost
// always must not be the one wearing an extra symbol.
test("plugged in but not charging draws the nob, not the bolt", () => {
    assert.equal(pickGlyph(held), Glyph.Nob);
});

test("a full battery draws the nob even while plugged in", () => {
    assert.equal(pickGlyph({ ...held, percentage: 1 }), Glyph.Nob);
    assert.equal(pickGlyph({ ...charging, percentage: 1 }), Glyph.Nob);
});

// Being attached to power is the fill's business. Two states share a glyph and are told apart
// by colour; two share a colour and are told apart by the glyph.
test("the glyph ignores whether the cable is in", () => {
    assert.equal(pickGlyph(held), pickGlyph(discharging));
    assert.equal(pickGlyph({ isCharging: true, isPluggedIn: false, percentage: 0.5 }), Glyph.Bolt);
});

test("the charging fill covers both plugged-in states and neither unplugged one", () => {
    assert.equal(usesChargingFill(charging), true);
    assert.equal(usesChargingFill(held), true);
    assert.equal(usesChargingFill(discharging), false);
});

test("the nob fills only at full", () => {
    assert.equal(nobFilled(discharging), false);
    assert.equal(nobFilled({ ...discharging, percentage: 1 }), true);
});
