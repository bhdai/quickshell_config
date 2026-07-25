.pragma library

function pickNetworkSymbol({ ethernet, wifiEnabled, wifiStatus, strength }) {
    if (ethernet)
        return "network-wired-symbolic";

    if (wifiEnabled) {
        switch (wifiStatus) {
        case "connected":
            if (strength > 66)
                return "network-wireless-signal-good-symbolic";
            if (strength > 33)
                return "network-wireless-signal-ok-symbolic";
            if (strength > 0)
                return "network-wireless-signal-weak-symbolic";
            else
                return "network-wireless-signal-none-symbolic";
        case "connecting":
            return "network-wireless-acquiring-symbolic";
        case "disconnected":
            return "network-wireless-signal-none-symbolic";
        default:
            return "network-wireless-offline-symbolic";
        }
    }
    return "network-wireless-disabled-symbolic";
}

// Returns a new array; the caller's list (a live QML model in the panel) is never reordered.
function sortWifiNetworks(list) {
    return [...list].sort((a, b) => {
        if (a.active && !b.active)
            return -1;
        if (!a.active && b.active)
            return 1;
        return b.strength - a.strength;
    });
}

// The tail beyond `limit` is what the panel's See-all chevron reveals. Returns a new array;
// the caller's list (a live QML model in the panel) is never sliced in place.
function visibleWifiNetworks(list, limit, expanded) {
    return expanded ? [...list] : list.slice(0, limit);
}

// Finds the saved connection profile for an SSID in `nmcli -g UUID,NAME,TYPE connection show`
// output, so the panel's gear can hand nm-connection-editor one specific network. Returns ""
// when the network has never been saved. Only wireless profiles match: a wired profile can
// carry the same name, and editing it would be the wrong network entirely.
function findWifiConnectionUuid(text, ssid) {
    if (!ssid)
        return "";

    const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
    const rep = new RegExp("\\\\:", "g");
    const rep2 = new RegExp(PLACEHOLDER, "g");

    for (const line of text.trim().split("\n")) {
        const fields = line.replace(rep, PLACEHOLDER).split(":");
        const name = fields[1]?.replace(rep2, ":") ?? "";
        const type = fields[2] ?? "";
        if (name === ssid && type.includes("wireless"))
            return fields[0] ?? "";
    }
    return "";
}

function parseConnectionStatus(buffer) {
    const lines = buffer.trim().split('\n');
    const connectivity = lines.pop();
    let hasEthernet = false;
    let hasWifi = false;
    let wifiStatus = "disconnected";
    lines.forEach(line => {
        if (line.includes("ethernet") && line.includes("connected"))
            hasEthernet = true;
        else if (line.includes("wifi:")) {
            if (line.includes("disconnected")) {
                wifiStatus = "disconnected";
            } else if (line.includes("connected")) {
                hasWifi = true;
                wifiStatus = "connected";

                if (connectivity === "limited") {
                    hasWifi = false;
                    wifiStatus = "limited";
                }
            } else if (line.includes("connecting")) {
                wifiStatus = "connecting";
            } else if (line.includes("unavailable")) {
                wifiStatus = "disabled";
            }
        }
    });
    return {
        wifiStatus,
        ethernet: hasEthernet,
        wifi: hasWifi
    };
}

function parseWifiNetworks(text) {
    const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
    const rep = new RegExp("\\\\:", "g");
    const rep2 = new RegExp(PLACEHOLDER, "g");

    const allNetworks = text.trim().split("\n").map(n => {
        const net = n.replace(rep, PLACEHOLDER).split(":");
        return {
            active: net[0] === "yes",
            strength: parseInt(net[1]),
            frequency: parseInt(net[2]),
            ssid: net[3]?.replace(rep2, ":") ?? "",
            bssid: net[4]?.replace(rep2, ":") ?? "",
            security: net[5] || ""
        };
    }).filter(n => n.ssid && n.ssid.length > 0);

    const networkMap = new Map();
    for (const network of allNetworks) {
        const existing = networkMap.get(network.ssid);
        if (!existing) {
            networkMap.set(network.ssid, network);
        } else {
            if (network.active && !existing.active) {
                networkMap.set(network.ssid, network);
            } else if (!network.active && !existing.active) {
                if (network.strength > existing.strength) {
                    networkMap.set(network.ssid, network);
                }
            }
        }
    }

    return Array.from(networkMap.values());
}
