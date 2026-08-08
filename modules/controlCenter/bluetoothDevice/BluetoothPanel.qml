import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
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
    // Everything the control center has left under its card.
    property real maxPanelHeight: 600

    // Fixed, and deliberately not sized to the list: discovery is live, so a panel that measured
    // its own content would change height whenever BlueZ found or dropped a device, and opening
    // one device's subpage would resize the panel around it. The list scrolls instead.
    implicitHeight: root.maxPanelHeight
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

        footerLeading: RippleButton {
            implicitHeight: 40
            implicitWidth: 140
            padding: 0
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colPrimary

            onClicked: {
                if (!root.adapter)
                    return;
                root.adapter.pairable = true;
                root.adapter.discovering = true;
            }

            contentItem: Text {
                text: "Pair new device"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.bold: true
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        ListView {
            id: deviceList
            anchors.fill: parent
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
