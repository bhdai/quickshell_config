import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root

    signal closePanel

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    // The device whose subpage is showing. Held while the subpage slides back out so its
    // content does not blank mid-animation; BlueZ dropping the device nulls it and closes.
    property BluetoothDevice detailDevice: null
    property bool detailOpen: false

    implicitHeight: 600
    // The subpage slides in from beyond the right edge.
    clip: true

    onDetailDeviceChanged: {
        if (!detailDevice)
            detailOpen = false;
    }

    DetailPanel {
        id: panel

        anchors.fill: parent
        title: "Bluetooth"
        subtitle: "Tap to connect or disconnect a device"
        scanning: root.adapter?.discovering ?? false
        switchLabel: "Use Bluetooth"
        switchChecked: root.adapter?.enabled ?? false

        onSwitchToggled: {
            const adapter = root.adapter;
            if (!adapter)
                return;
            // The switch only moves once BlueZ confirms, which invites a second press while
            // the adapter is still powering up or down — and BlueZ answers that one with
            // org.bluez.Error.Busy.
            if (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
                return;
            adapter.enabled = !adapter.enabled;
        }
        onDone: root.closePanel()

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0

                model: ScriptModel {
                    values: BluetoothStatus.sortDevices(Bluetooth.devices.values)
                }

                delegate: BluetoothDeviceItem {
                    required property BluetoothDevice modelData

                    device: modelData
                    // Not anchors to `parent`: a vertical ListView's contentItem carries no
                    // width of its own, so an anchored row collapses to nothing.
                    width: deviceList.width

                    onOpenDetails: {
                        root.detailDevice = device;
                        root.detailOpen = true;
                    }
                }
            }

            SplitTargetRow {
                Layout.fillWidth: true
                trailingVisible: false

                onBodyClicked: {
                    if (!root.adapter)
                        return;
                    root.adapter.pairable = true;
                    root.adapter.discovering = true;
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 12

                    // Bare `+` in the icon column: no circle, unlike the device rows.
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 40
                        text: "add"
                        iconSize: 24
                        color: Appearance.colors.colOnLayer0
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: "Pair new device"
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    BluetoothDeviceDetailPage {
        id: detailPage

        width: root.width
        height: root.height
        x: root.detailOpen ? 0 : root.width
        visible: x < root.width
        device: root.detailDevice

        onBack: root.detailOpen = false

        Behavior on x {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }
    }
}
