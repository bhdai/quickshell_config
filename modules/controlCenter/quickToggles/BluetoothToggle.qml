import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Hyprland

BigToggleButton {
    icon: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
    title: "Connected"
    subtitle: "Device Name"
}
