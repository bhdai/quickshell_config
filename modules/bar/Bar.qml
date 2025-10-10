import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    id: bar

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "changefloatingmode":
                Hyprland.refreshToplevels();
                break;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            color: "#2d2d2d"
            implicitHeight: 40

            // left section
            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                anchors.leftMargin: 5

                // distro logo
                Rectangle {
                    id: distroLogo
                    width: 35
                    height: 30
                    radius: 15
                    color: "#444444"
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰣇"
                        color: "#0e94d2"
                        font.bold: true
                        font.pixelSize: 20
                    }
                }
                WorkspaceIndicator {}
                ActiveWindow {}
            }

            // middle section
            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Notification {}
                TimeWidget {}
            }

            // right section
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 5
                spacing: 8

                Media {}

                SysTray {}
                SystemInfo {}
                PowerButton {}
            }

            // bind Pipewire objects to ensure properties are available
            PwObjectTracker {
                objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            }
        }
    }
}
