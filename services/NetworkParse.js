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

// The same thresholds `pickNetworkSymbol` uses, read out for the detail subpage's
// "Signal strength" row, so the words always agree with the icon above them.
function signalLabel(strength) {
    if (strength > 66)
        return "Excellent";
    if (strength > 33)
        return "Good";
    if (strength > 0)
        return "Weak";
    return "None";
}

// `mhz` is the channel centre nmcli reports (2437, 5805, …), reduced to the band a person
// recognises. The cuts are the band edges: 2.4 GHz ends at 2500, and 5 GHz ends where the
// 6 GHz band begins at 5925.
function frequencyLabel(mhz) {
    if (!mhz)
        return "";
    if (mhz < 2500)
        return "2.4 GHz";
    if (mhz < 5925)
        return "5 GHz";
    return "6 GHz";
}

// nmcli leaves SECURITY empty for an open network, which reads as a missing value rather
// than as the fact it is.
function securityLabel(security) {
    return security ? security : "None";
}

// NetworkManager's `connection.metered` is three-valued, and its default `unknown` means
// "let NetworkManager decide" rather than "unset".
function meteredLabel(metered) {
    if (metered === "yes")
        return "Metered";
    if (metered === "no")
        return "Not metered";
    return "Detect automatically";
}

// The line under the SSID on the detail subpage. Auto-connect is called out only when it is
// off: a network that reconnects by itself is the unremarkable case. Returns "" before the
// details query has answered, so the page shows no line rather than flashing a wrong one.
function connectionStatusLine({ state, autoconnect }) {
    if (!state)
        return "";
    const status = state === "activated" ? "Connected" : "Connecting…";
    return autoconnect ? status : `${status} • Auto-connect is off`;
}

function cidrToNetmask(prefix) {
    if (!(prefix >= 0 && prefix <= 32))
        return "";
    const octets = [];
    for (let i = 0; i < 4; ++i) {
        const bits = Math.min(Math.max(prefix - i * 8, 0), 8);
        octets.push(256 - Math.pow(2, 8 - bits));
    }
    return octets.join(".");
}

/**
 * Parses the concatenated output of
 *   nmcli -t -f connection.autoconnect,connection.metered,GENERAL.DEVICES,GENERAL.STATE,\
 *               IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS con show uuid <uuid>
 *   nmcli -t -f GENERAL.DEVICE,GENERAL.HWADDR dev show
 * into the object the Wi-Fi detail subpage reads. The MAC comes from the second command
 * because it is a property of the interface, not of the connection profile.
 *
 * This is not the escaped-colon format `parseWifiNetworks` handles. In nmcli's one-field-per-line
 * output the first colon is the separator and colons inside the value are left alone, so IPv6
 * addresses and MACs arrive verbatim and must be split on the first colon only.
 */
function parseConnectionDetails(text) {
    const fields = new Map();
    const macByDevice = new Map();
    const dns = [];
    let currentDevice = "";

    for (const line of (text ?? "").trim().split("\n")) {
        const separator = line.indexOf(":");
        if (separator < 0)
            continue;
        const key = line.slice(0, separator);
        const value = line.slice(separator + 1);

        if (key === "GENERAL.DEVICE")
            currentDevice = value;
        else if (key === "GENERAL.HWADDR")
            macByDevice.set(currentDevice, value);
        else if (key.indexOf("IP4.DNS") === 0 && value)
            dns.push(value);
        else
            fields.set(key, value);
    }

    const device = fields.get("GENERAL.DEVICES") ?? "";
    const address = fields.get("IP4.ADDRESS[1]") ?? "";
    const slash = address.indexOf("/");
    const ipv6 = fields.get("IP6.ADDRESS[1]") ?? "";

    return {
        device: device,
        state: fields.get("GENERAL.STATE") ?? "",
        autoconnect: fields.get("connection.autoconnect") === "yes",
        metered: fields.get("connection.metered") ?? "unknown",
        ipv4: slash < 0 ? address : address.slice(0, slash),
        netmask: slash < 0 ? "" : cidrToNetmask(parseInt(address.slice(slash + 1), 10)),
        gateway: fields.get("IP4.GATEWAY") ?? "",
        dns: dns,
        ipv6: ipv6.split("/")[0],
        mac: macByDevice.get(device) ?? ""
    };
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
