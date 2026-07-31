import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const modulePath = path.join(repoRoot, "modules", "wallpaper");
const module = read(modulePath, "WallpaperModule.qml");

test("one wallpaper panel follows every connected Quickshell screen", () => {
    const [variants] = blocks(module, "Variants");
    const [panel] = blocks(variants, "PanelWindow");

    assert.match(variants, /model: Quickshell\.screens/);
    assert.match(panel, /required property var modelData/);
    assert.match(panel, /screen: modelData/);
    assert.match(panel, /property string target: Wallpaper\.forMonitor\(modelData\.name\)/);
});

test("the wallpaper panel is a full-output click-through background surface", () => {
    const [panel] = blocks(module, "PanelWindow");

    assert.match(panel, /exclusionMode: ExclusionMode\.Ignore/);
    assert.match(panel, /WlrLayershell\.namespace: "quickshell:wallpaper"/);
    assert.match(panel, /WlrLayershell\.layer: WlrLayer\.Background/);
    for (const edge of ["top", "right", "bottom", "left"])
        assert.match(panel, new RegExp(`${edge}: true`));
    assert.match(panel, /color: Appearance\.colors\.colLayer0/);

    const [mask] = blocks(panel, "mask: Region");
    assert.ok(mask, "the panel has no input mask");
    assert.doesNotMatch(mask, /\b(item|width|height|regions)\s*:/);
});

test("the hard-cut image is asynchronous, uncached, cropped, and decode-bounded", () => {
    const [image] = blocks(module, "Image");

    assert.match(image, /anchors\.fill: parent/);
    assert.match(image, /source: wallpaperWindow\.target/);
    assert.match(image, /asynchronous: true/);
    assert.match(image, /cache: false/);
    assert.match(image, /fillMode: Image\.PreserveAspectCrop/);
    assert.match(image, /sourceSize\.width: wallpaperWindow\.width/);
    assert.match(image, /sourceSize\.height: wallpaperWindow\.height/);
});

test("only a reappearing output gets one bounded reattach", () => {
    const [timer] = blocks(module, "Timer");

    assert.match(module, /seenOutputs/);
    assert.match(module, /root\.hasSeen\(modelData\.name\)/);
    assert.match(timer, /interval: 100/);
    assert.match(timer, /repeat: false/);
    assert.match(timer, /wallpaperWindow\.reattaching = false/);
    assert.doesNotMatch(module, /3000|repeat: true/);
});

test("the root mounts the wallpaper module and the service owns all wallpaper IO", () => {
    const shell = read(repoRoot, "shell.qml");
    const service = read(repoRoot, "services", "Wallpaper.qml");

    assert.match(shell, /import qs\.modules\.wallpaper/);
    assert.match(shell, /WallpaperModule \{\}/);
    assert.match(service, /FileView\s*\{/);
    assert.match(service, /FolderListModel\s*\{/);
    assert.match(service, /IpcHandler\s*\{/);
    assert.doesNotMatch(module, /FileView|JsonAdapter|FolderListModel|IpcHandler/);
});

test("the wallpaper smoke fixture uses only tools installed by the smoke job", () => {
    const fixture = read(repoRoot, "tests", "wallpaper-service.sh");

    assert.doesNotMatch(fixture, /\bnode\b/);
});
