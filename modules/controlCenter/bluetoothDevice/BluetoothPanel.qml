import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    signal closePanel

    color: Colors.background
    radius: 20
    border.width: 1
    border.color: Colors.border

    implicitHeight: 600

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Bluetooth Settings"
                color: Colors.text
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

            RippleButton {
                text: "Done"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 35

                onClicked: root.closePanel()
            }
        }

        Rectangle {
            implicitHeight: 1
            Layout.fillWidth: true
            color: Colors.text
            opacity: 0.3
        }

        // Content area - placeholder for now
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Text {
                text: "Available Devices:"
                color: Colors.text
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.surface1
                radius: 10

                Text {
                    anchors.centerIn: parent
                    text: "Bluetooth device list will appear here"
                    color: Colors.subtext0
                    font.pixelSize: 13
                }
            }
        }
    }
}
