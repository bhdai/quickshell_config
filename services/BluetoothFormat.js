.pragma library

// `battery` is a 0..1 fraction, as BluetoothDevice reports it. Returns "" for an
// unpaired device: the caller decides whether an empty line is hidden or reserved.
function deviceStatusLine({ paired, connected, pairing, batteryAvailable, battery }) {
    if (pairing)
        return "Pairing…";
    if (!paired)
        return "";

    const status = connected ? "Connected" : "Paired";
    if (!batteryAvailable)
        return status;
    return `${status} • ${Math.round(battery * 100)}%`;
}

// `iconName` is BlueZ's freedesktop icon name, matched by substring because the
// same class arrives under several names ("audio-headset", "headset", ...).
function deviceSymbol(iconName) {
    const name = iconName ?? "";
    if (name.includes("headset"))
        return "audio-headset-symbolic";
    if (name.includes("headphones"))
        return "audio-headphones-symbolic";
    if (name.includes("audio"))
        return "audio-speakers-symbolic";
    if (name.includes("phone"))
        return "phone-apple-iphone-symbolic";
    if (name.includes("mouse"))
        return "input-mouse-symbolic";
    if (name.includes("keyboard"))
        return "input-keyboard-symbolic";
    return "bluetooth-active-symbolic";
}

// The same icon names as `deviceSymbol`, read out for the device subpage's "Device type" row.
function deviceTypeLabel(iconName) {
    const name = iconName ?? "";
    if (name.includes("headset"))
        return "Headset";
    if (name.includes("headphones"))
        return "Headphones";
    if (name.includes("audio"))
        return "Speaker";
    if (name.includes("phone"))
        return "Phone";
    if (name.includes("mouse"))
        return "Mouse";
    if (name.includes("keyboard"))
        return "Keyboard";
    return "Other";
}

// The battery on its own, for the subpage row that already carries a "Battery" label. "" when
// the device reports none, which is also the caller's cue to hide the row.
function batteryLabel({ batteryAvailable, battery }) {
    if (!batteryAvailable)
        return "";
    return `${Math.round(battery * 100)}%`;
}

// Returns a new array; the caller's list (a live QML model in the panel) is never reordered.
function sortDevices(list) {
    const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;

    return [...list].sort((a, b) => {
        const conn = (b.connected - a.connected) || (b.paired - a.paired);
        if (conn !== 0)
            return conn;

        const aIsMac = macRegex.test(a.name);
        const bIsMac = macRegex.test(b.name);
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;

        return a.name.localeCompare(b.name);
    });
}
