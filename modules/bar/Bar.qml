import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    id: bar

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

            RowLayout {
                anchors.fill: parent
                spacing: 15

                // left
                Item {
                    Layout.preferredWidth: parent.width * 0.3
                    Layout.fillHeight: true

                    WorkspaceIndicator {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width)
                        height: parent.height * 0.8
                    }
                }

                // center
                Item {
                    Layout.preferredWidth: parent.width * 0.4
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        text: Time.time
                        color: "white"
                        font.pixelSize: 14
                    }
                }

                // right
                Item {
                    Layout.preferredWidth: parent.width * 0.3
                    Layout.fillHeight: true

                    SystemInfo {
                        anchors.centerIn: parent
                        height: parent.height * 0.8
                    }
                }
            }
        }
    }
}
