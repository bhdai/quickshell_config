import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import "dashboard_metrics.js" as Metrics

/**
 * The surface behind the bar clock. It owns the fixed window, the focus grab, which
 * destination is showing, and the `dashboard` IPC target.
 *
 * Calendar and Wallpaper are the destinations. A further one is a name in `tabs` and a
 * branch in the card's pane loader; nothing here is per-destination.
 */
Scope {
    id: root

    property bool isOpen: false
    // Labels, lowercased to their IPC names. `currentTab` is always one of them.
    readonly property var tabs: ["Calendar", "Wallpaper"]
    property string currentTab: "calendar"

    // Every entry point through the bar lands on Calendar, whatever a previous IPC call
    // left showing.
    function toggle(): void {
        if (root.isOpen) {
            root.isOpen = false;
            return;
        }
        root.currentTab = "calendar";
        root.isOpen = true;
    }

    function knows(tab: string): bool {
        return root.tabs.some(label => label.toLowerCase() === tab);
    }

    onIsOpenChanged: {
        if (root.isOpen)
            Weather.refreshIfStale();
    }

    Loader {
        id: popupLoader
        active: root.isOpen

        sourceComponent: PanelWindow {
            id: popupPanel
            visible: root.isOpen

            exclusiveZone: 0
            implicitWidth: Metrics.WINDOW_W
            implicitHeight: Metrics.WINDOW_H

            WlrLayershell.namespace: "quickshell:dashboard"
            color: "transparent"

            anchors {
                top: true
            }

            HyprlandFocusGrab {
                windows: [popupPanel]
                active: popupLoader.active
                onCleared: () => {
                    if (!active)
                        root.isOpen = false;
                }
            }

            DashboardCard {
                anchors.centerIn: parent
                tabs: root.tabs
                currentTab: root.currentTab
                onTabSelected: tab => root.currentTab = tab
            }
        }
    }

    // Strings rather than exit codes: `qs ipc call` cannot distinguish a missing target
    // from a handler that failed, so every outcome names itself.
    IpcHandler {
        target: "dashboard"

        function toggle(): string {
            root.toggle();
            return root.isOpen ? "opened " + root.currentTab : "closed";
        }

        function open(tab: string): string {
            if (!root.knows(tab))
                return "unknown tab: " + tab;
            root.currentTab = tab;
            root.isOpen = true;
            return "opened " + tab;
        }

        function close(): string {
            root.isOpen = false;
            return "closed";
        }
    }
}
