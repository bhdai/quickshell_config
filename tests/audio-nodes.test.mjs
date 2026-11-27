import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { parseSinkAvailability, isOutputDevice, isAppStream, listedOutputs, outputLabel, outputSymbol, streamLabel, streamIconName, nodeRows } =
    loadQmlJs(new URL("../services/audio_nodes.js", import.meta.url), [
        "parseSinkAvailability",
        "isOutputDevice",
        "isAppStream",
        "listedOutputs",
        "outputLabel",
        "outputSymbol",
        "streamLabel",
        "streamIconName",
        "nodeRows",
    ]);

const audio = {};
const speaker = { id: 57, name: "alsa_output.Speaker__sink", isSink: true, isStream: false, audio, nickname: "Speaker", description: "Raptor Lake-P/U/H cAVS Speaker" };
const hdmi = { id: 54, name: "alsa_output.HDMI3__sink", isSink: true, isStream: false, audio, nickname: "HDMI / DisplayPort 3 Output", description: "Raptor Lake-P/U/H cAVS HDMI / DisplayPort 3 Output (Stereo)" };
const mic = { id: 59, name: "alsa_input.mic", isSink: false, isStream: false, audio };
const playback = { id: 80, name: "Firefox", isSink: true, isStream: true, audio };
const capture = { id: 81, name: "voxtype", isSink: false, isStream: true, audio };

test("a sink is available when any of its ports might be plugged in", () => {
    const json = JSON.stringify([
        { name: "hdmi", ports: [{ name: "[Out] HDMI3", availability: "not available" }] },
        { name: "speaker", ports: [{ name: "[Out] Speaker", availability: "availability unknown" }] },
        { name: "jack", ports: [{ availability: "not available" }, { availability: "available" }] },
        { name: "virtual", ports: [] },
    ]);
    assert.deepEqual(parseSinkAvailability(json), { hdmi: false, speaker: true, jack: true, virtual: true });
});

test("unreadable availability output hides nothing", () => {
    assert.deepEqual(parseSinkAvailability(""), {});
    assert.deepEqual(parseSinkAvailability("Connection failure"), {});
    assert.deepEqual(parseSinkAvailability("{}"), {});
});

test("only hardware sinks are output devices", () => {
    assert.equal(isOutputDevice(speaker), true);
    assert.equal(isOutputDevice(mic), false);
    assert.equal(isOutputDevice(playback), false);
    assert.equal(isOutputDevice({ ...speaker, audio: null }), false);
});

test("only playback streams are app streams", () => {
    assert.equal(isAppStream(playback), true);
    assert.equal(isAppStream(capture), false);
    assert.equal(isAppStream(speaker), false);
});

test("unplugged outputs are left out, but the current output always stays", () => {
    const nodes = [hdmi, speaker, mic, playback];
    assert.deepEqual(listedOutputs(nodes, { [hdmi.name]: false }, speaker), [speaker]);
    assert.deepEqual(listedOutputs(nodes, { [hdmi.name]: false }, hdmi), [hdmi, speaker]);
    assert.deepEqual(listedOutputs(nodes, {}, speaker), [hdmi, speaker]);
});

test("an output is named by its short nickname first", () => {
    assert.equal(outputLabel(speaker), "Speaker");
    assert.equal(outputLabel({ name: "x", description: "WH-1000XM4" }), "WH-1000XM4");
    assert.equal(outputLabel({ name: "bluez_output.x" }), "bluez_output.x");
    assert.equal(outputLabel(null), "Unknown output");
});

test("an output's symbol follows what kind of device it is", () => {
    assert.equal(outputSymbol(speaker, "audio-card-analog"), "speaker");
    assert.equal(outputSymbol(hdmi, "audio-card-analog"), "tv");
    assert.equal(outputSymbol({ name: "bluez_output.AA" }, "audio-headphones-bluetooth"), "headphones");
    assert.equal(outputSymbol({ name: "bluez_output.AA", description: "Soundcore" }, ""), "bluetooth");
    assert.equal(outputSymbol({ name: "usb", description: "USB Headset" }, ""), "headset_mic");
});

test("an app stream is named by its application first", () => {
    assert.equal(streamLabel({ "application.name": "Firefox", "media.name": "YouTube" }, { name: "n", description: "d" }), "Firefox");
    assert.equal(streamLabel({ "media.name": "YouTube" }, { name: "n", description: "" }), "YouTube");
    assert.equal(streamLabel({}, { name: "spotify" }), "spotify");
    assert.equal(streamLabel({}, null), "Unknown app");
});

test("an app stream's icon comes from its icon name, else its binary", () => {
    assert.equal(streamIconName({ "application.icon-name": "firefox", "application.process.binary": "firefox-bin" }), "firefox");
    assert.equal(streamIconName({ "application.process.binary": "spotify" }), "spotify");
    assert.equal(streamIconName({}), "");
});

test("rows carry only primitives, keyed so a reused id is a new row", () => {
    const rows = nodeRows([speaker, null, playback]);
    assert.deepEqual(rows, [
        { key: "57:alsa_output.Speaker__sink", id: 57, name: "alsa_output.Speaker__sink" },
        { key: "80:Firefox", id: 80, name: "Firefox" },
    ]);
});
