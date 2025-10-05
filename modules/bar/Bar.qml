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

                // left section
                RowLayout {
                    spacing: 10
                    anchors.leftMargin: 10
                    Layout.alignment: Qt.AlignVCenter

                    // distro logo
                    Rectangle {
                        id: distroLogo
                        width: 33
                        height: 30
                        radius: 20
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
                        text: Hyprland.activeToplevel?.title || "Desktop"
                        color: "white"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.maximumWidth: 200
                    }
                }

                // spacer 1
                Item {
                    Layout.fillWidth: true
                }

                // middle section
                RowLayout {
                    spacing: 15
                    Layout.alignment: Qt.AlignVCenter

                    Notification {}
                    Text {
                        text: Time.time
                        color: "white"
                        font.pixelSize: 14
                    }
                }

                // spacer 2
                Item {
                    Layout.fillWidth: true
                }

                // right section
                RowLayout {
                    anchors.rightMargin: 10
                    spacing: 10
                    Layout.alignment: Qt.AlignVCenter

                    SystemTray {}
                    SystemInfo {}
                    PowerButton {}
                }
            }

            // bind Pipewire objects to ensure properties are available
            PwObjectTracker {
                objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            }
        }
    }
}
