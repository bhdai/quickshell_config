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

    assert.match(area, /onClicked/);
    const focus = area.indexOf("forceActiveFocus()");
    const apply = area.search(/Wallpaper\.set\(/);
    assert.notEqual(focus, -1, "clicking a tile does not focus it");
    assert.notEqual(apply, -1, "clicking a tile does not reach the Wallpaper service");
    assert.ok(focus < apply, "the tile applies before it takes focus");

    // Applying is the whole interaction: the popup stays open and nothing else is written.
    assert.doesNotMatch(tile, /isOpen|close\(\)|stateAdapter|writeAdapter/);
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

test("the dashboard has exactly the two destinations and routes both to a pane", () => {
    assert.match(dashboard, /readonly property var tabs: \["Calendar", "Wallpaper"\]/);

    const [loader] = blocks(card, "Loader");
    assert.match(loader, /case "calendar":\s*return calendarComponent;/);
    assert.match(loader, /case "wallpaper":\s*return wallpaperComponent;/);
    // Anything else is no pane at all rather than a stale one left standing.
    assert.match(loader, /return null;/);
});
