import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { parseStartTime, formatElapsed } = loadQmlJs(
    new URL("../services/screen_recording.js", import.meta.url),
    ["parseStartTime", "formatElapsed"],
);

test("the recorder's own filename carries the start time", () => {
    // Exactly what `capture-screenrecording` writes: date +'%Y-%m-%d_%H-%M-%S'.
    assert.equal(
        parseStartTime("/home/dai/Videos/screenrecording-2026-08-16_19-30-05.mp4"),
        new Date(2026, 7, 16, 19, 30, 5).getTime(),
    );
});

test("the start time is read in local time, as the recorder stamped it", () => {
    // Reading it as UTC would put the clock hours out for most of the world, and the
    // recorder has no timezone in the name to correct with.
    const parsed = new Date(parseStartTime("screenrecording-2026-01-02_03-04-05.mp4"));
    assert.equal(parsed.getHours(), 3);
    assert.equal(parsed.getMinutes(), 4);
    assert.equal(parsed.getSeconds(), 5);
});

test("SCREENRECORD_DIR pointing somewhere else does not lose the timestamp", () => {
    assert.equal(
        parseStartTime("/mnt/scratch/deep/screenrecording-2026-08-16_19-30-05.mp4"),
        new Date(2026, 7, 16, 19, 30, 5).getTime(),
    );
});

test("a path with no usable timestamp reports none rather than a wrong one", () => {
    // A hand-written state file, a rename, or a half-flushed read: the indicator shows no
    // clock for these, which is honest, instead of counting from an invented instant.
    assert.equal(parseStartTime("/home/dai/Videos/demo.mp4"), null);
    assert.equal(parseStartTime(""), null);
    assert.equal(parseStartTime(null), null);
    assert.equal(parseStartTime(undefined), null);
});

test("an impossible date is rejected instead of rolling into a plausible one", () => {
    // Date(2026, 12, ...) silently becomes January 2027, which would show as a recording
    // that started months ago.
    assert.equal(parseStartTime("screenrecording-2026-13-16_19-30-05.mp4"), null);
    assert.equal(parseStartTime("screenrecording-2026-02-31_19-30-05.mp4"), null);
    assert.equal(parseStartTime("screenrecording-2026-08-16_25-30-05.mp4"), null);
    assert.equal(parseStartTime("screenrecording-2026-08-16_19-61-05.mp4"), null);
});

test("the clock stays narrow until it has to grow", () => {
    assert.equal(formatElapsed(0), "0:00");
    assert.equal(formatElapsed(7), "0:07");
    assert.equal(formatElapsed(70), "1:10");
    assert.equal(formatElapsed(599), "9:59");
    assert.equal(formatElapsed(600), "10:00");
});

test("past an hour the minutes pad so the clock stops jumping about", () => {
    assert.equal(formatElapsed(3600), "1:00:00");
    assert.equal(formatElapsed(3661), "1:01:01");
    assert.equal(formatElapsed(36000), "10:00:00");
});

test("a clock with nothing sane to count reads zero rather than NaN", () => {
    // elapsed is derived from a parsed start time; if that ever arrives unusable the bar
    // must not render "NaN:aN".
    assert.equal(formatElapsed(-5), "0:00");
    assert.equal(formatElapsed(NaN), "0:00");
    assert.equal(formatElapsed(undefined), "0:00");
    assert.equal(formatElapsed(1.9), "0:01");
});
