import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const logic = loadQmlJs(
    path.join(repoRoot, "services", "WallpaperLogic.js"),
    ["SUPPORTED_EXTENSIONS", "NAME_FILTERS", "hasSupportedExtension", "forMonitor", "cyclePath"],
);

test("wallpaper formats and folder filters are exactly the supported four", () => {
    assert.deepEqual(logic.SUPPORTED_EXTENSIONS, [".jpg", ".jpeg", ".png", ".bmp"]);
    assert.deepEqual(logic.NAME_FILTERS, ["*.jpg", "*.jpeg", "*.png", "*.bmp"]);
});

test("extension matching is case-insensitive and rejects deceptive suffixes", () => {
    for (const file of ["wall.jpg", "wall.JPEG", "/tmp/wall.PnG", "/tmp/wall.bMp"])
        assert.equal(logic.hasSupportedExtension(file), true, file);

    for (const file of ["wall.webp", "wall.jpg.tmp", "walljpeg", "wall.png/child", ""])
        assert.equal(logic.hasSupportedExtension(file), false, file);
});

test("a non-empty monitor override wins and otherwise falls back to global", () => {
    const overrides = {
        "DP-1": "/wall/secondary.png",
        "HDMI-A-1": "",
    };

    assert.equal(logic.forMonitor("/wall/global.jpg", overrides, "DP-1"), "/wall/secondary.png");
    assert.equal(logic.forMonitor("/wall/global.jpg", overrides, "HDMI-A-1"), "/wall/global.jpg");
    assert.equal(logic.forMonitor("/wall/global.jpg", overrides, "eDP-1"), "/wall/global.jpg");
    assert.equal(logic.forMonitor("", overrides, "eDP-1"), "");
});

test("cycling handles empty, unknown, forward, backward, and both wraps", () => {
    const paths = ["/wall/a.jpg", "/wall/b.jpg", "/wall/c.jpg"];

    assert.equal(logic.cyclePath([], "/wall/a.jpg", 1), "");
    assert.equal(logic.cyclePath(paths, "/outside/current.jpg", 1), "/wall/a.jpg");
    assert.equal(logic.cyclePath(paths, "/outside/current.jpg", -1), "/wall/c.jpg");
    assert.equal(logic.cyclePath(paths, "/wall/a.jpg", 1), "/wall/b.jpg");
    assert.equal(logic.cyclePath(paths, "/wall/b.jpg", -1), "/wall/a.jpg");
    assert.equal(logic.cyclePath(paths, "/wall/c.jpg", 1), "/wall/a.jpg");
    assert.equal(logic.cyclePath(paths, "/wall/a.jpg", -1), "/wall/c.jpg");
    assert.equal(logic.cyclePath(["/wall/only.jpg"], "/wall/only.jpg", 1), "/wall/only.jpg");
});

test("cycling never mutates the caller's path array", () => {
    const paths = ["/wall/b.jpg", "/wall/a.jpg"];
    const before = paths.slice();

    logic.cyclePath(paths, "/wall/b.jpg", 1);

    assert.deepEqual(paths, before);
});
