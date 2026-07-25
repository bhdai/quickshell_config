import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Hyprland

LongToggleTile {
    id: root

    readonly property BluetoothAdapter currentAdapter: Bluetooth.defaultAdapter

    signal openBluetoothPanel

    icon: BluetoothStatus.symbol
    toggled: BluetoothStatus.enabled
    title: {
        if (!toggled)
            return "Disabled";
        if (BluetoothStatus.isTransitioning)
            return "Connecting...";
        return BluetoothStatus.connected ? "Connected" : "Disconnected";
    }
    subtitle: {
        if (!toggled)
            return "";
        return BluetoothStatus.firstActiveDevice ? BluetoothStatus.firstActiveDevice.name : "No connected device";
    }

    onIconClicked: {
        currentAdapter.enabled = !currentAdapter.enabled;
    }

    onBodyClicked: {
        root.openBluetoothPanel();
    }
}
