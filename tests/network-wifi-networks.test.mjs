import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { parseWifiNetworks } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["parseWifiNetworks"],
);

test("escaped colons in SSIDs and BSSIDs are preserved", () => {
    assert.deepEqual(
        parseWifiNetworks(
            "no:72:5180:Cafe\\:Guest:AA\\:BB\\:CC\\:DD\\:EE\\:FF:WPA2\n",
        ),
        [
            {
                active: false,
                strength: 72,
                frequency: 5180,
                ssid: "Cafe:Guest",
                bssid: "AA:BB:CC:DD:EE:FF",
                security: "WPA2",
            },
        ],
    );
});

test("an active duplicate is kept over a stronger inactive network", () => {
    assert.deepEqual(
        parseWifiNetworks(
            [
                "no:90:5180:Home:AA\\:AA\\:AA\\:AA\\:AA\\:AA:WPA2",
                "yes:40:2412:Home:BB\\:BB\\:BB\\:BB\\:BB\\:BB:WPA2",
            ].join("\n"),
        ),
        [
            {
                active: true,
                strength: 40,
                frequency: 2412,
                ssid: "Home",
                bssid: "BB:BB:BB:BB:BB:BB",
                security: "WPA2",
            },
        ],
    );
});

test("the stronger inactive duplicate is kept", () => {
    assert.deepEqual(
        parseWifiNetworks(
            [
                "no:35:2412:Office:CC\\:CC\\:CC\\:CC\\:CC\\:CC:WPA2",
                "no:80:5180:Office:DD\\:DD\\:DD\\:DD\\:DD\\:DD:WPA2",
            ].join("\n"),
        ),
        [
            {
                active: false,
                strength: 80,
                frequency: 5180,
                ssid: "Office",
                bssid: "DD:DD:DD:DD:DD:DD",
                security: "WPA2",
            },
        ],
    );
});
