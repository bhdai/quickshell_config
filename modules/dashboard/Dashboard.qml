import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import "dashboard_metrics.js" as Metrics

/**
 * The surface behind the bar clock. It owns the window, the focus grab, which destination is
 * showing, and the `dashboard` IPC target.
 *
 * Calendar and Wallpaper are the destinations. A further one is a name in `tabs`, a branch in
 * the card's pane loader, and a pane naming the canvas it wants as its implicit size; nothing
 * here is per-destination, and nothing here decides how big any of them are.
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
            // Big enough for the largest destination and then fixed, so the card resizes
            // inside a surface that never moves. The window is wider than the card on every
            // tab but the widest; the mask is what keeps that border from swallowing the
            // clicks that dismiss the dashboard.
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

            // Only the card is clickable. Everything around it falls through to whatever is
            // under the dashboard, which is what clears the focus grab and closes it.
            mask: Region {
                item: card
            }

            DashboardCard {
                id: card
                // Hung from the top rather than centred: centring would walk the card up and
                // down the window as a destination taller or shorter than the last one
                // animated in, on top of the resize it is already doing.
                anchors.top: parent.top
                anchors.topMargin: Metrics.MARGIN
                anchors.horizontalCenter: parent.horizontalCenter
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
