import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.modules.common

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

            color: Colors.background
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
                    color: Colors.surface
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰣇"
                        color: Colors.archBlue
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
                StatusIcons {}
                BatteryIndicator {}
                PowerButton {}
            }

            // bind Pipewire objects to ensure properties are available
            PwObjectTracker {
                objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            }
        }
    }
}
