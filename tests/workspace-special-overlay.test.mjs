import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const indicator = read(repoRoot, "modules", "bar", "WorkspaceIndicator.qml");
const code = indicator.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");

// `blocks` finds every `Item {`, and the root and the row are both one. The row is the
// shortest block that declares `id: row`; the root is the only one that contains it.
function shortestBlockDeclaring(type, id) {
    const found = blocks(code, type).filter(block => new RegExp(`^\\s*id: ${id}$`, "m").test(block));
    assert.ok(found.length > 0, `no ${type} declaring id: ${id}`);
    return found.reduce((shortest, block) => (block.length < shortest.length ? block : shortest));
}

const row = shortestBlockDeclaring("Item", "row");
const overlay = shortestBlockDeclaring("Rectangle", "specialOverlay");

// The special is a state you are told about. Model membership cannot answer "is it on
// screen": a special sits in Hyprland.workspaces whenever it holds windows, reports
// active: false while visible, and lingers there for ~250 ms after a hide.
test("visibility comes from the activespecial event and nothing else", () => {
    const [connections] = blocks(code, "Connections");
    assert.match(connections, /target: Hyprland/);
    assert.match(connections, /function onRawEvent\(event\)/);
    assert.match(connections, /event\.name !== "activespecial"/);
    assert.match(connections, /WorkspaceModel\.parseActiveSpecial\(event\.data\)/);
});

test("only an event naming this bar's monitor moves this widget", () => {
    const [connections] = blocks(code, "Connections");
    assert.match(connections, /\.monitor === root\.screen\.name/);
});

test("nothing derives the special from the workspace list", () => {
    const writes = code.match(/^\s*root\.specialName = .*$/gm) ?? [];
    assert.equal(writes.length, 2, "specialName is written by the event handler and the seed read only");
    assert.doesNotMatch(code, /specialName\s*=.*Hyprland\.workspaces/);
    assert.doesNotMatch(code, /specialName:\s*(?!root\.specialName$).*workspaces/m);
});

// A special already raised when the shell starts — or, far more often, when a file save
// hot-reloads it — emits no event there is anything to replay.
test("a special already up at startup is seeded from a refreshed monitor snapshot", () => {
    assert.match(code, /Component\.onCompleted: Hyprland\.refreshMonitors\(\)/);

    const [seed] = blocks(code, "Timer");
    assert.match(seed, /lastIpcObject\?\.specialWorkspace\?\.name/);

    const [, interval] = seed.match(/interval: (\d+)/);
    assert.ok(Number(interval) >= 250, `seed read waits for the refresh, got ${interval} ms`);
});

test("the seed read only ever sets a name, never clears one", () => {
    const [seed] = blocks(code, "Timer");
    assert.match(seed, /!== ""/);
    assert.equal((seed.match(/root\.specialName = /g) ?? []).length, 1);
});

// The blur is what tells you something covers the desktop; the overlay says what.
test("the row blurs and shrinks behind one MultiEffect", () => {
    assert.match(row, /layer\.enabled:/);

    const [effect] = blocks(row, "MultiEffect");
    assert.match(effect, /blurEnabled: true/);
    assert.match(effect, /blur: root\.specialReveal/);
    assert.match(row, /scale: 1 - 0\.08 \* root\.specialReveal/);
});

// MultiEffect's blur radius is in source pixels, so end-4's 32 against a 26 px button is a
// ~1.23 ratio, not a number to copy onto an 18 px slot.
test("blurMax is derived from the slot width rather than copied", () => {
    assert.match(code, /property int specialBlurMax: Math\.round\(dotWidth \* 1\.23\)/);
    assert.doesNotMatch(code, /blurMax: \d/);
});

test("the overlay is a sibling of the row, not a child of it", () => {
    assert.doesNotMatch(row, /id: specialOverlay/);
    assert.match(overlay, /anchors\.centerIn: row/);
});

// This is what makes the treatment cost zero horizontal pixels: the row's slot count is
// the only thing the widget's width has ever depended on.
test("the widget is exactly as wide with a special raised as without", () => {
    assert.match(code, /^\s*implicitWidth: rowGeometry\.contentWidth$/m);
    assert.doesNotMatch(overlay, /implicitWidth|implicitHeight/);
});

test("the overlay is a filled layers glyph on a primary stadium", () => {
    assert.match(overlay, /color: Appearance\.colors\.colPrimary/);
    assert.match(overlay, /height: root\.activeSize/);
    assert.match(overlay, /radius: Appearance\.rounding\.full/);

    const [symbol] = blocks(overlay, "MaterialSymbol");
    assert.match(symbol, /text: "layers"/);
    assert.match(symbol, /fill: 1/);
    assert.match(symbol, /iconSize: Math\.round\(root\.activeSize \* 0\.65\)/);

    // The name is constant on this machine and the blur has already said "something is
    // covering the desktop", so there is no text to draw.
    assert.doesNotMatch(overlay, /StyledText|specialName/);
});

test("pointer over the widget suppresses the blur and fades the overlay out", () => {
    assert.match(code, /HoverHandler \{/);
    assert.match(code, /property real specialReveal: .*!peekHover\.hovered.*\? 1 : 0/);
    assert.match(overlay, /opacity: root\.specialReveal/);
});

// Peek is a read. Nothing in this widget raises, dismisses or renames a special: SUPER+s
// does both edges, and end-4's back-button toggle would turn the *unnamed* special on
// while a named one is up.
test("nothing in the widget touches compositor state for the special", () => {
    assert.doesNotMatch(code, /toggle_special/);
    assert.doesNotMatch(code, /BackButton/);

    const dispatches = code.match(/Hyprland\.dispatch\(.*$/gm) ?? [];
    assert.deepEqual(dispatches, ["Hyprland.dispatch(WorkspaceModel.focusCommand(slot.index + 1))"]);
});

// With peek kept you cannot have the pointer on the widget and a full blur at once, so
// gating clicks on the blur would only cover the transition — and swallowing a deliberate
// click during it is worse than honouring it. A raised special stays up across the focus,
// so the blur correctly persists.
test("per-dot clicks stay live while a special is raised", () => {
    const [mouseArea] = blocks(row, "MouseArea");
    assert.match(mouseArea, /onClicked: Hyprland\.dispatch/);
    assert.doesNotMatch(mouseArea, /enabled:|specialReveal|special\.visible/);
});

test("the blur and the peek both run on the shared elementMove token", () => {
    const [behavior] = blocks(code, "Behavior on specialReveal");
    assert.match(behavior, /Appearance\.animation\.elementMove\.numberAnimation/);

    assert.doesNotMatch(code, /elementMoveSmall/);
    assert.doesNotMatch(code, /duration: \d/);
    assert.doesNotMatch(code, /easing\.type: Easing\./);
});
