import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { visibleWifiNetworks } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["visibleWifiNetworks"],
);

function net(ssid, strength, active = false) {
    return { ssid, strength, active };
}

const scan = [net("Home", 90, true), net("Cafe", 70), net("Guest", 50), net("Far", 20)];

test("a collapsed list stops at the limit", () => {
    assert.deepEqual(visibleWifiNetworks(scan, 2, false), [net("Home", 90, true), net("Cafe", 70)]);
});

test("See all reveals the weaker tail", () => {
    assert.deepEqual(visibleWifiNetworks(scan, 2, true), scan);
});

test("a scan shorter than the limit shows whole", () => {
    assert.deepEqual(visibleWifiNetworks(scan, 10, false), scan);
});

test("the input array is left untouched", () => {
    const input = [...scan];
    visibleWifiNetworks(input, 1, false);
    assert.deepEqual(input, scan);
});

test("an empty scan stays empty", () => {
    assert.deepEqual(visibleWifiNetworks([], 5, false), []);
});
