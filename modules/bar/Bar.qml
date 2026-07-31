import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.dashboard

Scope {
    id: bar

    // One dashboard for the session, not one per output: it owns an IPC target, and every
    // bar's clock toggles the same surface.
    //
    // Not `id: dashboard`. TimeWidget has a property of that name, and an object's own
    // scope wins over the file's ids — so `dashboard: dashboard` below would bind the
    // widget to itself and leave it holding null.
    Dashboard {
        id: dashboardPopup
    }

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

            color: "transparent"
            implicitHeight: 40

            WlrLayershell.namespace: "quickshell:bar"

            Rectangle {
                anchors.fill: parent
                color: Appearance.m3colors.m3background

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
                        color: Appearance.colors.colLayer1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰣇"
                            color: Appearance.colors.colArchBlue
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

                    TimeWidget {
                        dashboard: dashboardPopup
                    }
                }

                // right section
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 5
                    spacing: 8

                    Media {}
                    Resources {}

                    SysTray {}
                    StatusIcons {}
                    BatteryIndicator {}
                    PowerButton {}
                }
            }

            // // bind Pipewire objects to ensure properties are available
            // PwObjectTracker {
            //     objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            // }
        }
    }
}
