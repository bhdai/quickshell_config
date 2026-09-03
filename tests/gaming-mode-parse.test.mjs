import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { activeFromBlurOption } = loadQmlJs(
    new URL("../services/GamingModeParse.js", import.meta.url),
    ["activeFromBlurOption"],
);

test("enabled blur means gaming mode is off", () => {
    const output = '{"option":"decoration:blur:enabled","bool":true,"set":true}';

    assert.equal(activeFromBlurOption(output), false);
});

test("disabled blur means gaming mode is on", () => {
    const output = '{"option":"decoration:blur:enabled","bool":false,"set":true}';

    assert.equal(activeFromBlurOption(output), true);
});

test("invalid output has no gaming-mode state", () => {
    assert.equal(activeFromBlurOption(""), null);
    assert.equal(activeFromBlurOption("not json"), null);
    assert.equal(activeFromBlurOption('{"option":"decoration:blur:enabled"}'), null);
});
