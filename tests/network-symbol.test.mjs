import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { pickNetworkSymbol } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["pickNetworkSymbol"],
);

test("ethernet uses the wired symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: true,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 100,
        }),
        "network-wired-symbolic",
    );
});

test("disabled wifi uses the disabled symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: false,
            wifiStatus: "connected",
            strength: 100,
        }),
        "network-wireless-disabled-symbolic",
    );
});

test("connected wifi above 66 percent uses the good signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 67,
        }),
        "network-wireless-signal-good-symbolic",
    );
});

test("connected wifi at 66 percent uses the okay signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 66,
        }),
        "network-wireless-signal-ok-symbolic",
    );
});

test("connected wifi at 34 percent uses the okay signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 34,
        }),
        "network-wireless-signal-ok-symbolic",
    );
});

test("connected wifi at 33 percent uses the weak signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 33,
        }),
        "network-wireless-signal-weak-symbolic",
    );
});

test("connected wifi at one percent uses the weak signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 1,
        }),
        "network-wireless-signal-weak-symbolic",
    );
});

test("connected wifi at zero percent uses the no signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connected",
            strength: 0,
        }),
        "network-wireless-signal-none-symbolic",
    );
});

test("connecting wifi uses the acquiring symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "connecting",
            strength: 0,
        }),
        "network-wireless-acquiring-symbolic",
    );
});

test("disconnected wifi uses the no signal symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "disconnected",
            strength: 100,
        }),
        "network-wireless-signal-none-symbolic",
    );
});

test("limited wifi uses the offline symbol", () => {
    assert.equal(
        pickNetworkSymbol({
            ethernet: false,
            wifiEnabled: true,
            wifiStatus: "limited",
            strength: 100,
        }),
        "network-wireless-offline-symbolic",
    );
});
