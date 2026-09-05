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

    // Stopgap for a defect in Quickshell's Hyprland singleton rather than in this config:
    // the startup snapshot's removal pass deletes workspaces created by events that arrive
    // while its reply is in flight, and switching workspace afterwards heals only the one
    // dot you land on. Mechanism and measurements: bhdai/quickshell_config#119. Why the
    // repair is unconditional, timed and lives here — rather than a sleep before launch, a
    // `hyprctl reload` kick, or a patched Quickshell: bhdai/quickshell_config#123.
    //
    // The two stages must not share a tick. refreshToplevels() is an async request, so the
    // `id = -1` ghosts it revives do not exist until its reply is parsed; refreshWorkspaces()
    // is what backfills their real ids through the name fallback, and it can only write over
    // entries that already exist. Issued from one handler the repair would hinge on the two
    // replies parsing in issue order, which the singleton promises nowhere. 500 ms is a wide
    // margin: request to parse measured 1-2 ms warm and 35-40 ms for the startup snapshot
    // itself across runs of the reproducer named below.
    //
    // Delete this block once `docs/research/workspace-startup-race/boot-trigger2.sh` (branch
    // `research/workspace-startup-race`, commit 9a1ec76) stops breaking a shell that does not
    // carry it. It still breaks one on Quickshell v0.3.0, and the defect is intact on upstream
    // master as of 2026-08-07.
    Timer {
        interval: 2000
        running: true
        onTriggered: {
            Hyprland.refreshToplevels();
            workspaceIdBackfill.start();
        }
    }

    Timer {
        id: workspaceIdBackfill
        interval: 500
        onTriggered: Hyprland.refreshWorkspaces()
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
                color: Appearance.colors.colBarBackground

                // left section
                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    anchors.leftMargin: 5

                    // distro logo. The pill it used to sit in carried the horizontal padding
                    // that keeps it off the screen edge and off the workspace dots, so that
                    // margin moves here rather than disappearing with the container.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 7
                        Layout.rightMargin: 7
                        text: "󰣇"
                        color: Appearance.colors.colArchBlue
                        font.bold: true
                        font.pixelSize: 20
                    }
                    WorkspaceIndicator {
                        screen: modelData
                    }
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
