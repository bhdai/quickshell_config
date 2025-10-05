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

            // left section
            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                anchors.leftMargin: 10

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
                Text {
                    id: activeWindowTitle
                    text: {
                        const activeWin = Hyprland.activeToplevel;
                        const activeWs = Hyprland.focusedMonitor?.activeWorkspace;
                        if (activeWin && activeWs && activeWin.workspace === activeWs) {
                            return activeWin.title || "Desktop";
                        } else {
                            return "Desktop";
                        }
                    }
                    color: "white"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.maximumWidth: 300
                }
            }

            // middle section
            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 15

                Notification {}
                Text {
                    text: Time.time
                    color: "white"
                    font.pixelSize: 14
                }
            }

            // right section
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                spacing: 10

                SystemTray {}
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
