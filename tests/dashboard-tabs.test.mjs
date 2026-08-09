import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const dashboardDir = path.join(repoRoot, "modules", "dashboard");

const dashboard = read(dashboardDir, "Dashboard.qml");
const tabBar = read(dashboardDir, "DashTabBar.qml");
const card = read(dashboardDir, "DashboardCard.qml");

// The icon is presentation, and it travels with the label in the one ordered model the tab
// bar reads. A destination that named no icon would draw an empty line above its label.
test("every destination names the symbol drawn above its label", () => {
    assert.match(dashboard, /\{ key: "dashboard", label: "Dashboard", icon: "dashboard" \}/);
    assert.match(dashboard, /\{ key: "wallpaper", label: "Wallpaper", icon: "wallpaper" \}/);
    assert.match(dashboard, /\{ key: "performance", label: "Performance", icon: "speed" \}/);
});

// The label stays at `small` deliberately. `smaller` would fit, but the indicator hugs the
// wider of the two lines, so a 12px label would narrow it on every tab.
test("a tab is a 24px symbol over a label at the small size", () => {
    const [icon] = blocks(tabBar, "MaterialSymbol");
    const [label] = blocks(tabBar, "Text");

    assert.match(icon, /text: tab\.modelData\.icon\b/);
    assert.match(icon, /iconSize: 24\b/);
    assert.match(label, /text: tab\.modelData\.label\b/);
    assert.match(label, /font\.pixelSize: Appearance\.font\.pixelSize\.small\b/);
});

// The whole cell is the hover target, so the whole cell is what lights up. Measured on the
// desktop: a state layer that hugged only the two lines lit from anywhere in the tab, which
// reads as the wrong shape responding. What the ripple leaves behind is a colour transition,
// not a spread from wherever the pointer entered.
test("the state layer is the tab the pointer is actually over", () => {
    const [pill] = blocks(tabBar, "Rectangle");

    assert.match(pill, /anchors\.fill: parent\b/);
    assert.match(pill, /radius: Appearance\.rounding\.small\b/);
    assert.match(pill, /color: hover\.hovered \? Appearance\.colors\.colLayer1Hover : "transparent"/);
    assert.match(tabBar, /HoverHandler \{\s*id: hover/);

    assert.doesNotMatch(tabBar, /RippleButton|ripple/i);
});

// The icon fills as its destination becomes current, over the same clock as the colour it is
// filling into, so the two read as one change of state rather than two.
test("becoming current fills the icon and takes both lines to the accent", () => {
    const [icon] = blocks(tabBar, "MaterialSymbol");
    const [label] = blocks(tabBar, "Text");
    const [fill] = blocks(icon, "Behavior on fill");

    assert.match(icon, /fill: tab\.active \? 1 : 0/);
    assert.match(fill, /duration: Appearance\.animation\.elementMove\.duration/);
    assert.match(fill, /easing\.bezierCurve: Appearance\.animation\.expressiveEffects/);

    for (const line of [icon, label]) {
        assert.match(line, /color: tab\.active \? Appearance\.colors\.colPrimary : Appearance\.colors\.colOnSurfaceVariant/);
        const [transition] = blocks(line, "Behavior on color");
        assert.match(transition, /duration: Appearance\.animation\.elementMove\.duration/);
        assert.match(transition, /easing\.type: Appearance\.animation\.elementMove\.type/);
    }
});

// The cell a tab was laid into is not the shape a reader sees, and the two lines are not the
// same width as each other. What the indicator may read is the wider of the two.
test("the indicator hugs the wider of the two lines", () => {
    const [delegate] = blocks(tabBar, "delegate: Item");

    assert.match(delegate, /readonly property real contentWidth: Math\.max\(icon\.implicitWidth, label\.implicitWidth\)/);
    assert.match(tabBar, /targetWidth: activeTab \? Math\.max\(root\.minimumIndicator, activeTab\.contentWidth\) : 0/);
    assert.match(tabBar, /height: root\.indicatorHeight\b/);
    assert.doesNotMatch(tabBar, /labelWidth|labelX/);
});

// A Behavior's NumberAnimation restarts from wherever it currently is every time its target
// moves, so an indicator aimed at geometry that is itself animating is re-pinned on every
// frame of the card's resize and only sets off once the card has already settled. The width
// the indicator is placed over has to be the one the card is travelling to.
test("the card publishes the width it is travelling to, ahead of the Behavior", () => {
    assert.match(card, /readonly property real settledWidth: Metrics\.cardWidth\(Metrics\.CANVAS\[transitionState\.destination\]\.width\)/);
    assert.match(card, /implicitWidth: root\.settledWidth\b/);

    const [bar] = blocks(card, "DashTabBar");
    assert.match(bar, /settledBarWidth: root\.settledWidth - 2 \* Metrics\.PAD/);
});

// The same stride idiom the workspace indicator is built from: a position is arithmetic from
// an index and a width that does not move, so the slide is one movement on one clock.
test("the indicator is placed by index arithmetic over the settled width", () => {
    assert.match(tabBar, /required property real settledBarWidth\b/);
    assert.match(tabBar, /readonly property int currentIndex: root\.tabs\.findIndex\(tab => tab\.key === root\.current\)/);

    const indicator = blocks(tabBar, "Rectangle").find(block => block.includes("id: indicator"));
    assert.match(indicator, /readonly property real stride: root\.settledBarWidth \/ repeater\.count/);
    assert.match(indicator, /readonly property real targetX: stride \* root\.currentIndex \+ \(stride - targetWidth\) \/ 2/);
});

// The one geometry the indicator may still read mid-move is the delegate's own content width,
// which is what its two lines drew and never depends on the cell they were laid into. A
// position published by the delegate is a laid-out one, and travels while the card resizes.
test("the delegate publishes no laid-out position", () => {
    const [delegate] = blocks(tabBar, "delegate: Item");

    assert.doesNotMatch(delegate, /contentX/);
    assert.doesNotMatch(tabBar, /activeTab\.x\b/);
});
