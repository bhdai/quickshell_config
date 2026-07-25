import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { sortWifiNetworks } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["sortWifiNetworks"],
);

function net(ssid, strength, active = false) {
    return { ssid, strength, active };
}

test("networks are ordered by descending signal strength", () => {
    assert.deepEqual(
        sortWifiNetworks([net("Weak", 20), net("Strong", 90), net("Mid", 55)]),
        [net("Strong", 90), net("Mid", 55), net("Weak", 20)],
    );
});

test("the active network comes first regardless of strength", () => {
    assert.deepEqual(
        sortWifiNetworks([net("Strong", 90), net("Home", 30, true), net("Mid", 55)]),
        [net("Home", 30, true), net("Strong", 90), net("Mid", 55)],
    );
});

test("the input array is left untouched", () => {
    const input = [net("Weak", 20), net("Strong", 90)];
    sortWifiNetworks(input);
    assert.deepEqual(input, [net("Weak", 20), net("Strong", 90)]);
});

test("an empty list stays empty", () => {
    assert.deepEqual(sortWifiNetworks([]), []);
});
