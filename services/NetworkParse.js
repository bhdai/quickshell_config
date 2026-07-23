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
