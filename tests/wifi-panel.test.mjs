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

// The panel wraps the chrome rather than being it, so the detail subpage has something to slide
// over — the same shape BluetoothPanel took for the same reason.
test("the Wi-Fi panel is the shared chrome, same as Bluetooth", () => {
    const source = read(wifiNetwork, "WiFiPanel.qml");

    assert.equal(rootType(source), "Item");
    assert.match(source, /DetailPanel\s*\{/);
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

test("the connected network is a full-accent pill whose gear opens its detail subpage", () => {
    const source = read(wifiNetwork, "WiFiNetworkItem.qml");

    assert.match(source, /colBackground:\s*root\.connected\s*\?\s*Appearance\.colors\.colPrimary/);
    assert.match(source, /connected\s*\?\s*Appearance\.colors\.colOnPrimary/);
    // The gear is the connected row's alone — the subpage describes a live connection, so there
    // is nothing for it to show about a network the machine is not on.
    assert.match(source, /trailingVisible:\s*root\.connected/);
    assert.match(source, /signal openDetails/);
    assert.match(source, /onTrailingClicked:\s*root\.openDetails\(\)/);
    assert.match(read(wifiNetwork, "WiFiPanel.qml"), /onOpenDetails:[\s\S]*detailOpen\s*=\s*true/);
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

test("the subpage slides over the panel and swallows the input meant for it", () => {
    const panel = read(wifiNetwork, "WiFiPanel.qml");
    const page = read(wifiNetwork, "WiFiNetworkDetailPage.qml");
    const slide = blocks(panel, "WiFiNetworkDetailPage")[0];

    assert.ok(slide, "the panel mounts the subpage");
    assert.match(slide, /x:\s*root\.detailOpen\s*\?\s*0\s*:\s*root\.width/);
    assert.match(slide, /Behavior on x/);
    assert.match(slide, /onBack:\s*root\.detailOpen\s*=\s*false/);

    // A Rectangle covers the panel visually but passes input straight through, so the rows
    // behind the subpage would keep taking the hover and the click.
    const swallower = blocks(page, "MouseArea")[0];
    assert.ok(swallower, "the subpage has a MouseArea");
    assert.match(swallower, /anchors\.fill:\s*parent/);
    assert.match(swallower, /hoverEnabled:\s*true/);
    assert.match(swallower, /acceptedButtons:\s*Qt\.AllButtons/);
});

// The page is defined by the connection it describes, so losing that connection — by Forget, by
// Disconnect, or by walking out of range — must take the page with it rather than leave it
// reporting an address the machine no longer holds.
test("the subpage closes as soon as the connection it describes ends", () => {
    const panel = read(wifiNetwork, "WiFiPanel.qml");
    const guard = blocks(panel, "function onActiveChanged()")[0];

    assert.ok(guard, "the panel watches the held network's active flag");
    assert.match(guard, /detailOpen\s*=\s*false/);
    assert.match(panel, /onDetailNetworkChanged:[\s\S]*detailOpen\s*=\s*false/);

    const page = read(wifiNetwork, "WiFiNetworkDetailPage.qml");
    for (const action of blocks(page, "CircleAction"))
        assert.match(action, /root\.back\(\)/, "every circle action leaves the page");
});

test("the subpage's actions and its editor all go through the service", () => {
    const page = read(wifiNetwork, "WiFiNetworkDetailPage.qml");
    const actions = blocks(page, "CircleAction");

    assert.equal(actions.length, 2, "Forget and Disconnect, and no Share");
    assert.match(actions[0], /label:\s*"Forget"/);
    assert.match(actions[0], /Network\.forgetWifiNetwork\(/);
    assert.match(actions[1], /label:\s*"Disconnect"/);
    assert.match(actions[1], /Network\.disconnectWifiNetwork\(\)/);
    assert.match(page, /Network\.openConnectionEditor\(root\.ssid\)/);
    assert.match(page, /Network\.setAutoconnect\(/);
});

// The page holds the access point the panel handed it rather than reading Network.active, so a
// disconnect does not gut its rows during the 300ms slide-out.
test("the subpage reads the network it was handed, not the live active one", () => {
    const page = read(wifiNetwork, "WiFiNetworkDetailPage.qml");

    assert.match(page, /property WifiAccessPoint network/);
    assert.doesNotMatch(page, /Network\.active\?\./);
    assert.match(read(wifiNetwork, "WiFiPanel.qml"), /property WifiAccessPoint detailNetwork/);
});

// Every row's wording is the parse library's, so the page cannot drift from the icons and
// labels the rest of the shell shows for the same numbers.
test("the subpage's row values come from the parse library", () => {
    const page = read(wifiNetwork, "WiFiNetworkDetailPage.qml");

    for (const helper of ["signalLabel", "frequencyLabel", "securityLabel", "meteredLabel", "connectionStatusLine"])
        assert.match(page, new RegExp(`Network\\.${helper}\\(`), `${helper} is the service's`);
});

test("connection details are fetched when the subpage opens, never polled", () => {
    const page = read(wifiNetwork, "WiFiNetworkDetailPage.qml");
    const service = read(repoRoot, "services", "Network.qml");

    assert.match(page, /onVisibleChanged:[\s\S]*Network\.refreshConnectionDetails\(/);
    assert.match(service, /function refreshConnectionDetails\(/);

    for (const file of qmlFilesIn(wifiNetwork))
        assert.doesNotMatch(read(file), /Timer\s*\{/, `${path.basename(file)} polls nothing`);
    // update() runs on every nmcli monitor event; the detail query must not ride along with it.
    assert.doesNotMatch(
        blocks(service, "function update()")[0],
        /refreshConnectionDetails/,
        "the details query stays off the monitor heartbeat",
    );
});

// nmcli accepts a profile name, but a profile's name is only conventionally its SSID — acting
// on a same-named profile of another network is silent, and deleting one is unrecoverable.
test("every per-network action keys on the profile uuid", () => {
    const service = read(repoRoot, "services", "Network.qml");

    assert.match(service, /function withConnectionUuid\(/);
    assert.match(service, /"connection", "delete", "uuid", uuid/);
    assert.match(service, /"connection", "down", "uuid", uuid/);
    assert.match(service, /"connection", "modify", "uuid", uuid/);

    const signatures = [
        "function forgetWifiNetwork(ssid: string): void",
        "function disconnectWifiNetwork(): void",
        "function setAutoconnect(ssid: string, enabled: bool): void",
        "function refreshConnectionDetails(ssid: string): void",
    ];
    for (const signature of signatures) {
        const body = blocks(service, signature)[0];
        assert.ok(body, `${signature} is still declared this way`);
        assert.match(body, /withConnectionUuid/, `${signature} resolves a uuid first`);
    }
});

test("the info row and circle action are shared chrome, not per-panel copies", () => {
    for (const name of ["InfoRow", "CircleAction"])
        assert.match(read(detailPanel, `${name}.qml`), /^import/, `${name}.qml is a file of its own`);

    // An inline `component` of the same name in either page would shadow the shared file.
    for (const file of [...qmlFilesIn(wifiNetwork), path.join(repoRoot, "modules", "controlCenter", "bluetoothDevice", "BluetoothDeviceDetailPage.qml")])
        assert.doesNotMatch(read(file), /component (InfoRow|CircleAction):/, `${path.basename(file)} defines neither inline`);
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
