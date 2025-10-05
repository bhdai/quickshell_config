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

                // Left Section: Distro logo -> Workspace indicator -> Current window title
                Item {
                    Layout.preferredWidth: parent.width * 0.3
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Distro Logo (Arch Linux)
                        Rectangle {
                            id: distroLogo
                            width: 24
                            height: 24
                            radius: 4
                            color: "#1793D1" // Arch Linux brand color

                            Text {
                                anchors.centerIn: parent
                                text: "A"
                                color: "white"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }

                        // Workspace Indicator
                        WorkspaceIndicator {
                            width: Math.min(implicitWidth, parent.width * 0.5)
                            height: parent.height * 0.8
                        }

                        // Current Window Title
                        Text {
                            id: activeWindowTitle
                            text: Hyprland.activeToplevel?.title || "Desktop"
                            color: "white"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // Middle Section: Notification -> Time
                Item {
                    Layout.preferredWidth: parent.width * 0.4
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 15

                        // Notification indicator
                        Notification {
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Time
                        Text {
                            text: Time.time
                            color: "white"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // Right Section: System tray -> Volume -> Wifi -> Bluetooth -> Battery -> Power button

                RowLayout {
                    Layout.preferredWidth: parent.width * 0.3
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignRight // Align this whole section to the right
                    anchors.rightMargin: 10
                    spacing: 10
                    layoutDirection: Qt.RightToLeft

                    // Power button
                    PowerButton {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // System Info (Volume, WiFi, Bluetooth, Battery)
                    SystemInfo {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // System Tray
                    SystemTray {
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // Bind Pipewire objects to ensure properties are available
            PwObjectTracker {
                objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            }
        }
    }
}
