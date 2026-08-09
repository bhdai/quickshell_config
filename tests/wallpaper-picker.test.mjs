import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const dashboardDir = path.join(repoRoot, "modules", "dashboard");

const pane = read(dashboardDir, "WallpaperPane.qml");
const tile = read(dashboardDir, "WallpaperTile.qml");
const card = read(dashboardDir, "DashboardCard.qml");
const dashboard = read(dashboardDir, "Dashboard.qml");
const tabBar = read(dashboardDir, "DashTabBar.qml");

// Two enumerators of the same directory would eventually disagree about what is in it and in
// what order, and the grid and IPC cycling would then be picking from different lists.
test("the grid views the service's library rather than enumerating its own", () => {
    assert.match(pane, /model: Wallpaper\.libraryModel/);
    assert.equal(blocks(pane, "FolderListModel").length, 0, "the picker builds its own enumerator");
    assert.doesNotMatch(pane, /folder:/);
});

test("the grid is the accepted four-column geometry with no chrome around it", () => {
    const [grid] = blocks(pane, "Grid");

    assert.match(grid, /columns: Metrics\.GRID_COLUMNS/);
    assert.match(grid, /columnSpacing: Metrics\.CELL_GAP_X/);
    assert.match(grid, /rowSpacing: Metrics\.CELL_GAP_Y/);

    for (const rejected of [/footer/i, /page/i, /sort/i, /browse/i, /filler/i, /FileDialog/])
        assert.doesNotMatch(pane, rejected, `the picker grew ${rejected} chrome`);
});

test("the cell is fixed at the metrics, so a sparse library does not stretch it", () => {
    assert.match(tile, /width: Metrics\.CELL_W/);
    assert.match(tile, /height: Metrics\.CELL_H/);
});

// Bounding both dimensions is what keeps sixteen 5K JPEGs from costing sixteen full-size
// textures; asynchronous is what keeps their decode off the frame that opened the tab.
test("thumbnails decode asynchronously into a bounded texture, clipped by the shared primitive", () => {
    const [image] = blocks(tile, "Image");

    assert.match(image, /asynchronous: true/);
    assert.match(image, /sourceSize\.width:/);
    assert.match(image, /sourceSize\.height:/);
    assert.match(image, /fillMode: Image\.PreserveAspectCrop/);

    assert.match(tile, /import Quickshell\.Widgets/);
    assert.ok(blocks(tile, "ClippingRectangle").length === 1, "the thumbnail is not clipped by ClippingRectangle");
});

test("a click focuses the tile and applies through the one service mutation IPC uses", () => {
    const [area] = blocks(tile, "MouseArea");
    const [activate] = blocks(tile, "function activate(): void");
    const [keys] = blocks(tile, "Keys.onPressed: event =>");

    assert.match(area, /onClicked/);
    const focus = area.indexOf("forceActiveFocus()");
    const apply = area.search(/root\.activate\(\)/);
    assert.notEqual(focus, -1, "clicking a tile does not focus it");
    assert.notEqual(apply, -1, "clicking a tile does not use the shared activation path");
    assert.ok(focus < apply, "the tile applies before it takes focus");
    assert.match(activate, /Wallpaper\.set\(root\.path\)/);
    assert.match(keys, /root\.activate\(\)/);
    assert.equal(tile.match(/Wallpaper\.set\(/g)?.length, 1,
        "an input method bypasses the shared activation path");

    // Applying is the whole interaction: the popup stays open and nothing else is written.
    assert.doesNotMatch(tile, /isOpen|close\(\)|stateAdapter|writeAdapter/);
});

test("the active Wallpaper tab and any tile form the two-stop Tab loop", () => {
    const [tabKeys] = blocks(tabBar, "Keys.onPressed: event =>");
    const [tileKeys] = blocks(tile, "Keys.onPressed: event =>");

    assert.match(tabKeys, /Qt\.Key_Tab/);
    assert.match(tabKeys, /focusEntry\(\)/);
    assert.match(tabBar, /Keys\.priority: Keys\.BeforeItem/);
    assert.match(tileKeys, /Qt\.Key_Tab/);
    assert.match(tileKeys, /Qt\.Key_Backtab/);
    assert.match(tileKeys, /tabRequested\(\)/);
    assert.match(tile, /Keys\.priority: Keys\.BeforeItem/);
});

test("tiles bind only the specified arrows and activation keys", () => {
    const [keys] = blocks(tile, "Keys.onPressed: event =>");

    for (const key of ["Left", "Right", "Up", "Down", "Return", "Enter", "Space"])
        assert.match(keys, new RegExp(`Qt\\.Key_${key}`), `missing ${key}`);
    for (const key of ["H", "J", "K", "L", "PageUp", "PageDown", "Home", "End"])
        assert.doesNotMatch(keys, new RegExp(`Qt\\.Key_${key}\\b`), `added ${key}`);
});

// A tile that painted itself applied on click would lie for as long as the decode takes, and
// keep lying if the decode fails.
test("applied is the service's committed state and pending is visibly not it", () => {
    assert.match(tile, /property bool applied: .*Wallpaper\.wallpaper/);
    assert.match(tile, /property bool pending: .*Wallpaper\.pendingPath/);
});

test("hover, focus, pending and applied are four distinct treatments", () => {
    const treatments = [/containsMouse/, /activeFocus/, /root\.pending/, /root\.applied/];
    for (const treatment of treatments)
        assert.match(tile, treatment, `the tile has no ${treatment} treatment`);
});

test("focus and applied rings use the same tile bounds", () => {
    const rings = blocks(tile, "Rectangle");
    const applied = rings.find(block => /visible: root\.applied/.test(block));
    const focused = rings.find(block => /visible: root\.activeFocus/.test(block));

    assert.match(applied, /anchors\.fill: parent/);
    assert.match(focused, /anchors\.fill: parent/);
    assert.doesNotMatch(focused, /anchors\.margins/);
    assert.match(applied, /radius: Appearance\.rounding\.small/);
    assert.match(focused, /radius: Appearance\.rounding\.small/);
});

// An applied wallpaper from outside the library has no cell, and #96 refuses to invent one.
test("nothing is drawn for a wallpaper the library does not contain", () => {
    assert.doesNotMatch(pane, /synthetic|banner|outsideLibrary/i);
    assert.doesNotMatch(tile, /synthetic|banner|outsideLibrary/i);
});

test("an empty library is one message naming the directory and what it accepts", () => {
    const [message] = blocks(pane, "Text");

    assert.match(message, /Wallpaper\.library\b/);
    // The filters the model actually applies, so the message cannot claim a format the
    // library would then ignore.
    assert.match(message, /Wallpaper\.libraryModel\.nameFilters/);
});

test("the dashboard has exactly the three destinations and routes each to a pane", () => {
    assert.match(dashboard, /readonly property var tabs: \[\s*\{ key: "dashboard", label: "Dashboard", icon: "dashboard" \},\s*\{ key: "wallpaper", label: "Wallpaper", icon: "wallpaper" \},\s*\{ key: "performance", label: "Performance", icon: "speed" \}\s*\]/);

    const [routing] = blocks(card, "function componentFor(key: string): Component");
    const [loader] = blocks(card, "Loader");
    assert.match(routing, /case "dashboard":\s*return dashboardComponent;/);
    assert.match(routing, /case "wallpaper":\s*return wallpaperComponent;/);
    assert.match(routing, /case "performance":\s*return performanceComponent;/);
    // Anything else is no pane at all rather than a stale one left standing.
    assert.match(routing, /return null;/);
    assert.match(loader, /active: transitionState\.requestedKeys\.includes\(segment\.destinationKey\)/);
    assert.match(loader, /sourceComponent: transitionState\.componentFor\(segment\.destinationKey\)/);
});
