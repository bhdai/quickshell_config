import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { signalLabel, frequencyLabel, securityLabel, meteredLabel, connectionStatusLine, pickNetworkSymbol } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["signalLabel", "frequencyLabel", "securityLabel", "meteredLabel", "connectionStatusLine", "pickNetworkSymbol"],
);

test("signalLabel names each band the icon distinguishes", () => {
    assert.equal(signalLabel(100), "Excellent");
    assert.equal(signalLabel(67), "Excellent");
    assert.equal(signalLabel(66), "Good");
    assert.equal(signalLabel(34), "Good");
    assert.equal(signalLabel(33), "Weak");
    assert.equal(signalLabel(1), "Weak");
    assert.equal(signalLabel(0), "None");
});

// The row sits directly under the signal icon, so a strength that reads "Excellent" must never
// pair with the icon for a weaker band.
test("signalLabel agrees with the icon at every threshold", () => {
    const iconFor = strength => pickNetworkSymbol({
        ethernet: false,
        wifiEnabled: true,
        wifiStatus: "connected",
        strength,
    });
    const expected = {
        Excellent: "network-wireless-signal-good-symbolic",
        Good: "network-wireless-signal-ok-symbolic",
        Weak: "network-wireless-signal-weak-symbolic",
        None: "network-wireless-signal-none-symbolic",
    };
    for (let strength = 0; strength <= 100; ++strength)
        assert.equal(iconFor(strength), expected[signalLabel(strength)], `strength ${strength}`);
});

test("frequencyLabel reduces a channel centre to its band", () => {
    assert.equal(frequencyLabel(2437), "2.4 GHz");
    assert.equal(frequencyLabel(2484), "2.4 GHz");
    assert.equal(frequencyLabel(5180), "5 GHz");
    assert.equal(frequencyLabel(5805), "5 GHz");
    assert.equal(frequencyLabel(5955), "6 GHz");
    assert.equal(frequencyLabel(7115), "6 GHz");
});

test("frequencyLabel returns nothing for an unscanned network", () => {
    assert.equal(frequencyLabel(0), "");
    assert.equal(frequencyLabel(NaN), "");
});

test("securityLabel names an open network instead of leaving the row blank", () => {
    assert.equal(securityLabel(""), "None");
    assert.equal(securityLabel("WPA2 WPA3"), "WPA2 WPA3");
});

test("meteredLabel spells out NetworkManager's three states", () => {
    assert.equal(meteredLabel("yes"), "Metered");
    assert.equal(meteredLabel("no"), "Not metered");
    assert.equal(meteredLabel("unknown"), "Detect automatically");
    assert.equal(meteredLabel(""), "Detect automatically");
});

test("connectionStatusLine calls out auto-connect only when it is off", () => {
    assert.equal(
        connectionStatusLine({ state: "activated", autoconnect: true }),
        "Connected",
    );
    assert.equal(
        connectionStatusLine({ state: "activated", autoconnect: false }),
        "Connected • Auto-connect is off",
    );
    assert.equal(
        connectionStatusLine({ state: "activating", autoconnect: true }),
        "Connecting…",
    );
});

// The subpage renders before its details query answers; a line saying "Connecting…" over a
// network that is plainly connected is worse than no line at all.
test("connectionStatusLine says nothing until the details arrive", () => {
    assert.equal(connectionStatusLine({}), "");
    assert.equal(connectionStatusLine({ state: "", autoconnect: false }), "");
});
