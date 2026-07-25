import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { blocks, read, rootType } from "./qml-source.mjs";

// Like the Bluetooth panel's tests: nothing here renders (there is no display in CI), so these
// pin the wiring the acceptance criteria name — which chrome the panel is built from, where its
// order and icons come from, and that deep configuration still reaches the native editor.
const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const detailPanel = path.join(repoRoot, "modules", "controlCenter", "detailPanel");
const wifiNetwork = path.join(repoRoot, "modules", "controlCenter", "wifiNetwork");

function qmlFilesIn(directory) {
    return readdirSync(directory)
        .filter(name => name.endsWith(".qml"))
        .map(name => path.join(directory, name));
}

test("the Wi-Fi panel is the shared chrome, same as Bluetooth", () => {
    const source = read(wifiNetwork, "WiFiPanel.qml");

    assert.equal(rootType(source), "DetailPanel");
    assert.match(source, /import qs\.modules\.controlCenter\.detailPanel/);
    assert.match(source, /title:\s*"Wi-Fi"/);
    assert.match(source, /switchLabel:\s*"Use Wi-Fi"/);
});

test("the Use Wi-Fi switch both reflects and drives the radio", () => {
    const source = read(wifiNetwork, "WiFiPanel.qml");

    assert.match(source, /switchChecked:\s*Network\.wifiEnabled/);
    assert.match(source, /onSwitchToggled:[\s\S]*Network\.toggleWifi\(\)/);
});

test("the scan indicator follows the radio's scanning state", () => {
    assert.match(read(wifiNetwork, "WiFiPanel.qml"), /scanning:\s*Network\.wifiScanning/);
});

test("the footer is Advanced plus the chrome's Done, with Details and Share Wi-Fi gone", () => {
    const advanced = blocks(read(wifiNetwork, "WiFiPanel.qml"), "footerLeading: RippleButton")[0];

    assert.ok(advanced, "the panel fills the footer slot");
    assert.match(advanced, /"Advanced"/);
    assert.match(advanced, /Network\.openConnectionEditor\(\)/);
    assert.match(read(detailPanel, "DetailPanel.qml"), /"Done"/);

    for (const file of qmlFilesIn(wifiNetwork)) {
        const source = read(file);
        assert.doesNotMatch(source, /"Details"/, `${path.basename(file)} has no Details button`);
        assert.doesNotMatch(source, /Share Wi-Fi/, `${path.basename(file)} has no Share Wi-Fi`);
    }
});

test("network rows are the shared split-target row", () => {
    assert.equal(rootType(read(wifiNetwork, "WiFiNetworkItem.qml")), "SplitTargetRow");
});

test("the connected network is a full-accent pill whose gear opens the native editor", () => {
    const source = read(wifiNetwork, "WiFiNetworkItem.qml");

    assert.match(source, /colBackground:\s*root\.connected\s*\?\s*Appearance\.colors\.colPrimary/);
    assert.match(source, /connected\s*\?\s*Appearance\.colors\.colOnPrimary/);
    // The gear is the connected row's alone — nothing else in the list is configurable.
    assert.match(source, /trailingVisible:\s*root\.connected/);
    assert.match(source, /onTrailingClicked:[\s\S]*Network\.openConnectionEditor\(root\.network\?\.ssid/);
});

test("secure networks show a lock and expand the inline password field in place", () => {
    const source = read(wifiNetwork, "WiFiNetworkItem.qml");

    assert.match(source, /isSecure/);
    assert.match(source, /"channel-secure-symbolic"/);
    assert.match(source, /MaterialTextField\s*\{/);
    assert.match(source, /askingPassword/);
    assert.match(source, /Network\.changePassword\(/);
});

test("See all reveals the weaker tail through the library, not a slice in QML", () => {
    const source = read(wifiNetwork, "WiFiPanel.qml");

    assert.match(source, /"See all"/);
    assert.match(source, /showAll\s*=\s*!root\.showAll/);
    assert.match(source, /Network\.visibleWifiNetworks\(/);

    for (const file of qmlFilesIn(wifiNetwork))
        assert.doesNotMatch(read(file), /\.slice\(/, `${path.basename(file)} slices nothing itself`);
});

test("order and signal icons come from the parse library", () => {
    const panel = read(wifiNetwork, "WiFiPanel.qml");
    const item = read(wifiNetwork, "WiFiNetworkItem.qml");

    assert.match(panel, /Network\.sortWifiNetworks\(/);
    assert.match(item, /Network\.networkSymbol\(/);

    for (const file of qmlFilesIn(wifiNetwork))
        assert.doesNotMatch(read(file), /strength\s*[<>]/, `${path.basename(file)} thresholds nothing itself`);
});

// The panel asks the service to open a network; resolving the profile behind an SSID is
// nmcli's business and stays behind the service's Process.
test("the editor launch and its uuid lookup live in the service", () => {
    const service = read(repoRoot, "services", "Network.qml");

    assert.match(service, /function openConnectionEditor\(/);
    assert.match(service, /NetworkParse\.findWifiConnectionUuid\(/);
    assert.match(service, /"nm-connection-editor", "-e", uuid/);

    for (const file of qmlFilesIn(wifiNetwork))
        assert.doesNotMatch(read(file), /nmcli|nm-connection-editor/, `${path.basename(file)} runs no command itself`);
});

test("the Wi-Fi panel stays on colors.* tokens", () => {
    const offenders = qmlFilesIn(wifiNetwork).flatMap(file =>
        read(file).split("\n")
            .map((line, index) => ({ line, at: `${path.basename(file)}:${index + 1}` }))
            .filter(({ line }) => line.includes("Appearance.m3colors."))
            .map(({ at }) => at),
    );

    assert.deepEqual(offenders, []);
});

// The filled row is one shape behind both targets; two separately filled buttons would show
// the seam, and the Bluetooth rows must stay bare.
test("the split-target row paints one background and defaults to bare", () => {
    const source = read(detailPanel, "SplitTargetRow.qml");

    assert.match(source, /property color colBackground:\s*"transparent"/);
    assert.match(source, /property color colTrailing/);
    assert.match(source, /property color colDivider/);
});
