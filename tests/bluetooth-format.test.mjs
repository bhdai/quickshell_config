import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { deviceStatusLine, deviceSymbol, deviceTypeLabel, batteryLabel, sortDevices } = loadQmlJs(
    new URL("../services/BluetoothFormat.js", import.meta.url),
    ["deviceStatusLine", "deviceSymbol", "deviceTypeLabel", "batteryLabel", "sortDevices"],
);

test("an unpaired device has no status line", () => {
    assert.equal(
        deviceStatusLine({ paired: false, connected: false, batteryAvailable: false, battery: 0 }),
        "",
    );
});

test("an unpaired device has no status line even while connected", () => {
    assert.equal(
        deviceStatusLine({ paired: false, connected: true, batteryAvailable: true, battery: 0.8 }),
        "",
    );
});

test("a paired but disconnected device reads Paired", () => {
    assert.equal(
        deviceStatusLine({ paired: true, connected: false, batteryAvailable: false, battery: 0 }),
        "Paired",
    );
});

test("a connected device reads Connected", () => {
    assert.equal(
        deviceStatusLine({ paired: true, connected: true, batteryAvailable: false, battery: 0 }),
        "Connected",
    );
});

test("an available battery is appended as a rounded percentage", () => {
    assert.equal(
        deviceStatusLine({ paired: true, connected: true, batteryAvailable: true, battery: 0.8 }),
        "Connected • 80%",
    );
});

test("a fractional battery level is rounded to the nearest percent", () => {
    assert.equal(
        deviceStatusLine({ paired: true, connected: true, batteryAvailable: true, battery: 0.375 }),
        "Connected • 38%",
    );
});

test("battery is also shown for a paired but disconnected device", () => {
    assert.equal(
        deviceStatusLine({ paired: true, connected: false, batteryAvailable: true, battery: 0.5 }),
        "Paired • 50%",
    );
});

test("a pairing device reads Pairing whatever else it reports", () => {
    assert.equal(
        deviceStatusLine({ paired: false, connected: false, pairing: true, batteryAvailable: false, battery: 0 }),
        "Pairing…",
    );
    assert.equal(
        deviceStatusLine({ paired: true, connected: true, pairing: true, batteryAvailable: true, battery: 0.8 }),
        "Pairing…",
    );
});

test("headset icons map to the headset symbol", () => {
    assert.equal(deviceSymbol("audio-headset"), "audio-headset-symbolic");
});

test("headphone icons map to the headphones symbol", () => {
    assert.equal(deviceSymbol("audio-headphones"), "audio-headphones-symbolic");
});

test("generic audio icons map to the speakers symbol", () => {
    assert.equal(deviceSymbol("audio-card"), "audio-speakers-symbolic");
});

test("headset wins over the audio substring it contains", () => {
    assert.equal(deviceSymbol("audio-headset"), "audio-headset-symbolic");
    assert.equal(deviceSymbol("audio-headphones"), "audio-headphones-symbolic");
});

test("phone icons map to the phone symbol", () => {
    assert.equal(deviceSymbol("phone"), "phone-apple-iphone-symbolic");
});

test("mouse icons map to the mouse symbol", () => {
    assert.equal(deviceSymbol("input-mouse"), "input-mouse-symbolic");
});

test("keyboard icons map to the keyboard symbol", () => {
    assert.equal(deviceSymbol("input-keyboard"), "input-keyboard-symbolic");
});

test("an unrecognised icon falls back to the bluetooth symbol", () => {
    assert.equal(deviceSymbol("video-display"), "bluetooth-active-symbolic");
});

test("a missing icon falls back to the bluetooth symbol", () => {
    assert.equal(deviceSymbol(""), "bluetooth-active-symbolic");
    assert.equal(deviceSymbol(undefined), "bluetooth-active-symbolic");
});

test("each device class has a readable type label", () => {
    assert.equal(deviceTypeLabel("audio-headset"), "Headset");
    assert.equal(deviceTypeLabel("audio-headphones"), "Headphones");
    assert.equal(deviceTypeLabel("audio-card"), "Speaker");
    assert.equal(deviceTypeLabel("phone"), "Phone");
    assert.equal(deviceTypeLabel("input-mouse"), "Mouse");
    assert.equal(deviceTypeLabel("input-keyboard"), "Keyboard");
});

test("an unrecognised or missing icon has a generic type label", () => {
    assert.equal(deviceTypeLabel("video-display"), "Other");
    assert.equal(deviceTypeLabel(""), "Other");
    assert.equal(deviceTypeLabel(undefined), "Other");
});

test("battery reads as a rounded percentage when the device reports one", () => {
    assert.equal(batteryLabel({ batteryAvailable: true, battery: 0.8 }), "80%");
    assert.equal(batteryLabel({ batteryAvailable: true, battery: 0.375 }), "38%");
});

test("battery is empty when the device reports none", () => {
    assert.equal(batteryLabel({ batteryAvailable: false, battery: 0.8 }), "");
});

function device(name, { connected = false, paired = false } = {}) {
    return { name, connected, paired };
}

test("connected devices come first", () => {
    assert.deepEqual(
        sortDevices([device("Aa"), device("Zz", { connected: true, paired: true })]),
        [device("Zz", { connected: true, paired: true }), device("Aa")],
    );
});

test("paired devices come before unpaired ones", () => {
    assert.deepEqual(
        sortDevices([device("Aa"), device("Zz", { paired: true })]),
        [device("Zz", { paired: true }), device("Aa")],
    );
});

test("named devices come before MAC-address names", () => {
    assert.deepEqual(
        sortDevices([device("AA-BB-CC-DD-EE-FF"), device("Zz")]),
        [device("Zz"), device("AA-BB-CC-DD-EE-FF")],
    );
});

test("devices of equal rank are ordered alphabetically", () => {
    assert.deepEqual(
        sortDevices([device("Mouse"), device("Airpods"), device("Zen")]),
        [device("Airpods"), device("Mouse"), device("Zen")],
    );
});

test("connection rank outranks the named-before-MAC rule", () => {
    assert.deepEqual(
        sortDevices([device("Airpods"), device("AA-BB-CC-DD-EE-FF", { connected: true, paired: true })]),
        [device("AA-BB-CC-DD-EE-FF", { connected: true, paired: true }), device("Airpods")],
    );
});

test("the input array is left untouched", () => {
    const input = [device("Zz"), device("Aa")];
    sortDevices(input);
    assert.deepEqual(input, [device("Zz"), device("Aa")]);
});

test("an empty list stays empty", () => {
    assert.deepEqual(sortDevices([]), []);
});
