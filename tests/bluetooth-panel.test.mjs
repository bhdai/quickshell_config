import assert from "node:assert/strict";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { blocks, read, rootType } from "./qml-source.mjs";

// The panel has no unit-test seam beyond BluetoothFormat.js — there is no display in CI, so
// nothing here renders. These tests pin the wiring the acceptance criteria name: which
// component a surface is built from, which service its data comes from, and the pairing
// invariant, all of which a refactor could silently drop.
const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const widgets = path.join(repoRoot, "modules", "common", "widgets");
const detailPanel = path.join(repoRoot, "modules", "controlCenter", "detailPanel");
const bluetoothDevice = path.join(repoRoot, "modules", "controlCenter", "bluetoothDevice");

function qmlFilesIn(directory) {
    return readdirSync(directory)
        .filter(name => name.endsWith(".qml"))
        .map(name => path.join(directory, name));
}

test("StyledSwitch is a shared common widget wrapping Switch", () => {
    assert.ok(existsSync(path.join(widgets, "StyledSwitch.qml")));
    assert.equal(rootType(read(widgets, "StyledSwitch.qml")), "Switch");
});

test("StyledSwitch reports toggled() without writing checked, so the caller's binding lives", () => {
    const source = read(widgets, "StyledSwitch.qml");

    assert.match(source, /toggled\(\)/);
    assert.doesNotMatch(source, /^\s*(root\.)?checked\s*=/m, "StyledSwitch must not assign checked");
    assert.match(source, /checkable:\s*false/);
});

test("the shared chrome lives outside the Bluetooth panel, ready for the Wi-Fi panel", () => {
    for (const name of ["DetailPanel", "ScanIndicator", "SwitchRow", "SplitTargetRow"])
        assert.ok(existsSync(path.join(detailPanel, `${name}.qml`)), `${name}.qml exists`);
});

test("the chrome carries the header, indicator, switch row and Done footer", () => {
    const source = read(detailPanel, "DetailPanel.qml");

    assert.match(source, /ScanIndicator\s*\{/);
    assert.match(source, /SwitchRow\s*\{/);
    assert.match(source, /"Done"/);
    // Centered header: title and subtitle both align to the panel's horizontal centre.
    assert.equal((source.match(/Layout\.alignment:\s*Qt\.AlignHCenter/g) ?? []).length >= 3, true);
});

test("the switch row is a StyledSwitch", () => {
    assert.match(read(detailPanel, "SwitchRow.qml"), /StyledSwitch\s*\{/);
});

test("the Bluetooth panel is built on the shared chrome", () => {
    const source = read(bluetoothDevice, "BluetoothPanel.qml");

    assert.match(source, /import qs\.modules\.controlCenter\.detailPanel/);
    assert.match(source, /DetailPanel\s*\{/);
    assert.match(source, /switchLabel:\s*"Use Bluetooth"/);
});

test("the Use Bluetooth switch both reflects and drives the adapter", () => {
    const panel = blocks(read(bluetoothDevice, "BluetoothPanel.qml"), "DetailPanel")[0];

    assert.match(panel, /switchChecked:.*enabled/);
    assert.match(panel, /onSwitchToggled:[\s\S]*enabled\s*=/);
});

test("the scan indicator follows the adapter's discovering state", () => {
    const panel = blocks(read(bluetoothDevice, "BluetoothPanel.qml"), "DetailPanel")[0];

    assert.match(panel, /scanning:.*discovering/);
});

test("Pair new device sits in the footer and drives discovery", () => {
    const chrome = read(detailPanel, "DetailPanel.qml");
    const pairButton = blocks(read(bluetoothDevice, "BluetoothPanel.qml"), "footerLeading: RippleButton")[0];

    assert.match(chrome, /property Component footerLeading/);
    assert.ok(pairButton, "the panel fills the footer slot");
    assert.match(pairButton, /"Pair new device"/);
    assert.match(pairButton, /discovering\s*=\s*true/);
});

test("device rows are split-target: body connects, gear opens the subpage", () => {
    const source = read(bluetoothDevice, "BluetoothDeviceItem.qml");

    assert.equal(rootType(source), "SplitTargetRow");
    assert.match(source, /onBodyClicked:[\s\S]*connect\(\)/);
    assert.match(source, /onBodyClicked:[\s\S]*disconnect\(\)/);
    assert.match(source, /onTrailingClicked:[\s\S]*openDetails\(\)/);
});

test("the device subpage exposes forget, auto-connect, battery and type behind a back arrow", () => {
    const source = read(bluetoothDevice, "BluetoothDeviceDetailPage.qml");

    assert.match(source, /signal\s+back/);
    assert.match(source, /forget\(\)/);
    assert.match(source, /trusted/);
    assert.match(source, /batteryLabel/);
    assert.match(source, /deviceTypeLabel/);
});

// The rounded ends belong to the first and last *shown* row, and the battery row is conditional
// — a group shaped by declaration order flattens the wrong edge on a device with no battery.
test("the subpage's settings are one shaped group, skipping hidden rows", () => {
    assert.match(read(bluetoothDevice, "BluetoothDeviceDetailPage.qml"), /CardGroup\s*\{/);

    const group = read(widgets, "CardGroup.qml");

    assert.match(group, /\.visible/);
    assert.match(group, /visibleChanged\.connect/);
});

// CardGroup shapes a row by writing its corners, and every link of that chain is a plain
// property forward: drop one and the card silently keeps the wrong shape.
test("per-corner radii reach the switch row's card through RippleButton", () => {
    const button = read(widgets, "RippleButton.qml");
    const row = read(detailPanel, "SwitchRow.qml");

    for (const corner of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
        assert.match(button, new RegExp(`property real ${corner}`), `RippleButton takes ${corner}`);
        assert.match(row, new RegExp(`property alias ${corner}`), `SwitchRow forwards ${corner}`);
    }
});

// A Rectangle covers the panel visually but passes input straight through, so the rows behind
// the subpage kept taking the hover and the click.
test("the subpage swallows the input meant for the panel it covers", () => {
    const source = read(bluetoothDevice, "BluetoothDeviceDetailPage.qml");
    const swallower = blocks(source, "MouseArea")[0];

    assert.ok(swallower, "the subpage has a MouseArea");
    assert.match(swallower, /anchors\.fill:\s*parent/);
    assert.match(swallower, /hoverEnabled:\s*true/);
    assert.match(swallower, /acceptedButtons:\s*Qt\.AllButtons/);
});

test("pairing never pre-trusts an unpaired device", () => {
    const source = read(bluetoothDevice, "BluetoothDeviceItem.qml");
    const guard = blocks(source, "function onPairedChanged()");

    assert.equal(guard.length, 1, "the paired-flip guard is still there");
    assert.match(guard[0], /trusted\s*=\s*true/);

    const trustingLines = qmlFilesIn(bluetoothDevice).flatMap(file =>
        read(file).split("\n")
            .map((line, index) => ({ line, at: `${path.basename(file)}:${index + 1}` }))
            .filter(({ line }) => /trusted\s*=\s*true/.test(line))
            .map(({ at }) => at),
    );

    assert.equal(trustingLines.length, 1, `trust is granted in one place only, got ${trustingLines}`);
});

test("status lines, symbols and order come from the format library", () => {
    const item = read(bluetoothDevice, "BluetoothDeviceItem.qml");
    const panel = read(bluetoothDevice, "BluetoothPanel.qml");

    assert.match(item, /BluetoothStatus\.deviceStatusLine\(/);
    assert.match(item, /BluetoothStatus\.deviceSymbol\(/);
    assert.match(panel, /BluetoothStatus\.sortDevices\(/);

    for (const file of qmlFilesIn(bluetoothDevice))
        assert.doesNotMatch(read(file), /Math\.round\(/, `${path.basename(file)} formats nothing itself`);
});

// Found the hard way: `list<BluetoothDevice>` made QML coerce the adapter's QList<QObject*>
// element-wise, fail, and hand the sort an empty list — a silent empty device list, no warning.
test("the device-list re-export takes its argument untyped", () => {
    const source = read(repoRoot, "services", "BluetoothStatus.qml");

    assert.match(source, /function sortDevices\(devices\)/);
    assert.doesNotMatch(source, /function sortDevices\(devices\s*:/);
});

test("the panel and its chrome stay on colors.* tokens", () => {
    const offenders = [...qmlFilesIn(detailPanel), ...qmlFilesIn(bluetoothDevice)].flatMap(file =>
        read(file).split("\n")
            .map((line, index) => ({ line, at: `${path.basename(file)}:${index + 1}` }))
            .filter(({ line }) => line.includes("Appearance.m3colors."))
            .map(({ at }) => at),
    );

    assert.deepEqual(offenders, []);
});
