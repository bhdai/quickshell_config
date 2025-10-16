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
    icon: BluetoothStatus.connected ? "bluetooth-active-symbolic" : BluetoothStatus.enabled ? "bluetooth-disconnected-symbolic" : "bluetooth-disabled-symbolic"
    title: "Connected"
    subtitle: "Device Name"
}
