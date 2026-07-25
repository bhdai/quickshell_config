import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

/**
 * One device in the Bluetooth panel's list. The body is the whole connection lifecycle —
 * pair, connect, disconnect — and the gear hands the device to the panel's detail subpage.
 */
SplitTargetRow {
    id: root

    required property BluetoothDevice device

    signal openDetails

    onBodyClicked: {
        if (!root.device)
            return;
        if (!root.device.paired) {
            // Some adapters come up non-pairable, and BlueZ then refuses the pair outright.
            if (Bluetooth.defaultAdapter && !Bluetooth.defaultAdapter.pairable)
                Bluetooth.defaultAdapter.pairable = true;
            // Do NOT pre-trust: trusting an unpaired device makes BlueZ auto-connect it on
            // sight, so a failed pair leaves it bouncing connect/disconnect. Trust + connect
            // only once pairing actually succeeds (see the Connections below).
            root.device.pair();
        } else if (root.device.connected) {
            root.device.disconnect();
        } else {
            root.device.connect();
        }
    }

    onTrailingClicked: root.openDetails()

    Connections {
        target: root.device
        function onPairedChanged() {
            if (root.device?.paired) {
                root.device.trusted = true;
                root.device.connect();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 40
            implicitHeight: 40
            radius: width / 2
            color: root.device?.connected ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveEffects
                }
            }

            CustomIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: BluetoothStatus.deviceSymbol(root.device?.icon ?? "")
                colorize: true
                color: root.device?.connected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.device?.name || "Unknown device"
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: BluetoothStatus.deviceStatusLine(root.device)
                visible: text.length > 0
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }
    }
}
