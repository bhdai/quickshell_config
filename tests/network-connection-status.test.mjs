import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { parseConnectionStatus } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["parseConnectionStatus"],
);

test("connected wifi reports an active wireless connection", () => {
    assert.deepEqual(
        parseConnectionStatus("wifi:connected\nfull\n"),
        {
            wifiStatus: "connected",
            ethernet: false,
            wifi: true,
        },
    );
});

test("connected ethernet reports an active wired connection", () => {
    assert.deepEqual(
        parseConnectionStatus("ethernet:connected\nwifi:disconnected\nfull\n"),
        {
            wifiStatus: "disconnected",
            ethernet: true,
            wifi: false,
        },
    );
});

test("connecting wifi reports the in-progress state", () => {
    assert.deepEqual(
        parseConnectionStatus("wifi:connecting\nnone\n"),
        {
            wifiStatus: "connecting",
            ethernet: false,
            wifi: false,
        },
    );
});

test("disconnected wifi reports no active connection", () => {
    assert.deepEqual(
        parseConnectionStatus("wifi:disconnected\nnone\n"),
        {
            wifiStatus: "disconnected",
            ethernet: false,
            wifi: false,
        },
    );
});

test("unavailable wifi reports the disabled state", () => {
    assert.deepEqual(
        parseConnectionStatus("wifi:unavailable\nnone\n"),
        {
            wifiStatus: "disabled",
            ethernet: false,
            wifi: false,
        },
    );
});

test("limited connectivity downgrades a connected wifi device", () => {
    assert.deepEqual(
        parseConnectionStatus("wifi:connected\nlimited\n"),
        {
            wifiStatus: "limited",
            ethernet: false,
            wifi: false,
        },
    );
});
