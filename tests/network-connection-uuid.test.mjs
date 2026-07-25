import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { findWifiConnectionUuid } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["findWifiConnectionUuid"],
);

const listing = [
    "2b8b41df-1a2e-491d-8c58-6104eb3b1d47:Pixel_4181:802-11-wireless",
    "15cfe019-3371-4e9a-a390-279213f0ca49:lo:loopback",
    "e6184c1d-71ff-4aed-8a02-26b855bce5c4:FPT Software Guest:802-11-wireless",
].join("\n");

test("the saved connection's uuid comes back for its ssid", () => {
    assert.equal(
        findWifiConnectionUuid(listing, "FPT Software Guest"),
        "e6184c1d-71ff-4aed-8a02-26b855bce5c4",
    );
});

test("a non-wireless connection of the same name is never matched", () => {
    const text = [
        "aaaaaaaa-0000-0000-0000-000000000000:Office:ethernet",
        "bbbbbbbb-0000-0000-0000-000000000000:Office:802-11-wireless",
    ].join("\n");

    assert.equal(findWifiConnectionUuid(text, "Office"), "bbbbbbbb-0000-0000-0000-000000000000");
});

// nmcli escapes the field separator inside a value, so an SSID with a colon arrives as `a\:b`.
test("an ssid containing a colon still matches", () => {
    const text = "cccccccc-0000-0000-0000-000000000000:Cafe\\: Free:802-11-wireless";

    assert.equal(findWifiConnectionUuid(text, "Cafe: Free"), "cccccccc-0000-0000-0000-000000000000");
});

test("an unsaved network has no uuid", () => {
    assert.equal(findWifiConnectionUuid(listing, "Neighbour"), "");
});

test("an empty ssid matches nothing", () => {
    assert.equal(findWifiConnectionUuid(listing, ""), "");
});

test("empty nmcli output yields no uuid", () => {
    assert.equal(findWifiConnectionUuid("", "Pixel_4181"), "");
});
