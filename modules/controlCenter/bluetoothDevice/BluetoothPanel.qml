import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Bluetooth

Rectangle {
    id: root

    signal closePanel

    color: Colors.background
    radius: 20
    border.width: 1
    border.color: Colors.border

    implicitHeight: 600

    ColumnLayout {
        id: bluetoothPanelLayout
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header
        Text {
            text: "Bluetooth devices"
            color: Colors.text
            font.pixelSize: 18
            font.bold: true
            Layout.fillWidth: true
        }

        Rectangle {
            implicitHeight: 1
            Layout.fillWidth: true
            color: Colors.text
            opacity: 0.3
            visible: !(Bluetooth.defaultAdapter?.discovering ?? false)
            Layout.leftMargin: -bluetoothPanelLayout.anchors.margins
            Layout.rightMargin: -bluetoothPanelLayout.anchors.margins
        }

        ProgressBar {
            indeterminate: true
            Material.accent: Colors.primary
            visible: Bluetooth.defaultAdapter?.discovering ?? false
            Layout.fillWidth: true
            Layout.topMargin: -8
            Layout.bottomMargin: -8
            Layout.leftMargin: -bluetoothPanelLayout.anchors.margins
            Layout.rightMargin: -bluetoothPanelLayout.anchors.margins
        }

        ListView {
            Layout.fillHeight: true
            Layout.fillWidth: true

            Layout.leftMargin: -bluetoothPanelLayout.anchors.margins + 1 // for the border
            Layout.rightMargin: -bluetoothPanelLayout.anchors.margins + 1

            clip: true
            spacing: 0

            model: ScriptModel {
                values: [...Bluetooth.devices.values].sort((a, b) => {
                    // Connected -> paired -> others
                    let conn = (b.connected - a.connected) || (b.paired - a.paired);
                    if (conn !== 0)
                        return conn;

                    // Ones with meaningful names before MAC addresses
                    const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
                    const aIsMac = macRegex.test(a.name);
                    const bIsMac = macRegex.test(b.name);
                    if (aIsMac !== bIsMac)
                        return aIsMac ? 1 : -1;

                    // Alphabetical by name
                    return a.name.localeCompare(b.name);
                })
            }
            delegate: BluetoothDeviceItem {
                required property BluetoothDevice modelData
                device: modelData
                anchors {
                    left: parent?.left
                    right: parent?.right
                }
            }
        }

        Rectangle {
            implicitHeight: 1
            Layout.fillWidth: true
            color: Colors.text
            opacity: 0.3
            Layout.leftMargin: -bluetoothPanelLayout.anchors.margins
            Layout.rightMargin: -bluetoothPanelLayout.anchors.margins
        }

        RowLayout {
            spacing: 4

            RippleButton {
                id: detailButton
                implicitHeight: 36
                implicitWidth: 80
                padding: 14
                buttonRadius: 9999
                colBackground: Colors.background

                contentItem: Text {
                    anchors.fill: parent
                    anchors.leftMargin: detailButton.padding
                    anchors.rightMargin: detailButton.padding
                    text: "Details"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    font.bold: true
                    color: detailButton.enabled ? Colors.text : Colors.background
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RippleButton {
                id: doneButton
                implicitHeight: 36
                implicitWidth: 80
                padding: 14
                buttonRadius: 9999
                colBackground: Colors.background

                contentItem: Text {
                    anchors.fill: parent
                    anchors.leftMargin: doneButton.padding
                    anchors.rightMargin: doneButton.padding
                    text: "Done"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    font.bold: true
                    color: doneButton.enabled ? Colors.text : Colors.background
                }

                onClicked: root.closePanel()
            }
        }
    }
}
