import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

/**
 * One device's settings, pushed in over the Bluetooth panel by its gear. Only BlueZ-backed
 * rows are here: everything shown is a property of the device itself.
 *
 * `device` is null while no subpage is open and goes null if BlueZ drops the device, so every
 * read of it is guarded.
 */
Rectangle {
    id: root

    property BluetoothDevice device

    signal back

    color: Appearance.colors.colLayer0
    radius: 20
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    // The subpage only covers the panel visually: a Rectangle consumes no input, so without
    // this the panel's rows underneath still take the hover (and the click). Declared first,
    // so the page's own controls sit above it.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: Qt.ArrowCursor
    }

    component InfoRow: Rectangle {
        id: infoRow

        property string label
        property string value

        Layout.fillWidth: true
        implicitHeight: 56
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: infoRow.label
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            Text {
                text: infoRow.value
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    component CircleAction: ColumnLayout {
        id: circleAction

        property string symbol
        property string label

        signal triggered

        spacing: 6

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 56
            implicitHeight: 56
            padding: 0
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colPrimary

            onClicked: circleAction.triggered()

            contentItem: MaterialSymbol {
                text: circleAction.symbol
                iconSize: 24
                color: Appearance.colors.colOnSecondaryContainer
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: circleAction.label
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                padding: 0
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colPrimary

                onClicked: root.back()

                contentItem: MaterialSymbol {
                    text: "arrow_back"
                    iconSize: 22
                    color: Appearance.colors.colOnLayer0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Device details"
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.large
                font.bold: true
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            implicitWidth: 88
            implicitHeight: 88
            radius: width / 2
            color: Appearance.colors.colSecondaryContainer

            CustomIcon {
                anchors.centerIn: parent
                width: 40
                height: 40
                source: BluetoothStatus.deviceSymbol(root.device?.icon ?? "")
                colorize: true
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.device?.name || "Unknown device"
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.larger
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: BluetoothStatus.deviceStatusLine(root.device)
            visible: text.length > 0
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 32

            CircleAction {
                symbol: "delete"
                label: "Forget"
                // The device leaves the adapter's list with it, taking this subpage's subject.
                onTriggered: {
                    root.device?.forget();
                    root.back();
                }
            }

            CircleAction {
                symbol: root.device?.connected ? "bluetooth_disabled" : "bluetooth_connected"
                label: root.device?.connected ? "Disconnect" : "Connect"
                onTriggered: {
                    if (!root.device)
                        return;
                    if (root.device.connected)
                        root.device.disconnect();
                    else
                        root.device.connect();
                }
            }
        }

        CardGroup {
            Layout.fillWidth: true
            Layout.topMargin: 12

            SwitchRow {
                Layout.fillWidth: true
                label: "Connect automatically"
                checked: root.device?.trusted ?? false
                onToggled: {
                    if (root.device)
                        root.device.trusted = !root.device.trusted;
                }
            }

            InfoRow {
                label: "Battery"
                value: BluetoothStatus.batteryLabel(root.device)
                visible: value.length > 0
            }

            InfoRow {
                label: "Device type"
                value: BluetoothStatus.deviceTypeLabel(root.device?.icon ?? "")
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
