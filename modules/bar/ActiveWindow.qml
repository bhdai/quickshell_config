import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    implicitWidth: backgroundRect.implicitWidth
    implicitHeight: backgroundRect.implicitHeight
    hoverEnabled: true

    readonly property var activeWin: Hyprland.activeToplevel
    readonly property var activeWs: Hyprland.focusedMonitor?.activeWorkspace
    readonly property bool isWinActiveOnWs: activeWin && activeWs && activeWin?.workspace === activeWs

    readonly property var desktopEntry: isWinActiveOnWs ? DesktopEntries.heuristicLookup(activeWin.wayland?.appId || "") : null

    WrapperRectangle {
        id: backgroundRect
        color: root.containsMouse ? "#555555" : "#444444"
        radius: 20
        margin: 5

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        leftMargin: 10
        rightMargin: 10

        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            IconImage {
                id: appIcon

                visible: isWinActiveOnWs && desktopEntry && desktopEntry.icon

                source: Quickshell.iconPath(desktopEntry?.icon || "", true)

                implicitSize: 20
            }

            Text {
                text: isWinActiveOnWs ? (activeWin.title || "Untitled Window") : "Desktop"
                color: "white"
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.maximumWidth: 300
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // lazy loaded tooltip
    Timer {
        id: tooltipTimer
        interval: 500
        running: root.containsMouse && root.isWinActiveOnWs
        onTriggered: tooltipLoader.active = true
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: ActiveWindowTooltip {
            activeWin: root.activeWin
            anchorItem: root
        }
    }

    // reset tooltip when mouse leaves
    onContainsMouseChanged: {
        if (!containsMouse) {
            tooltipTimer.stop();
            tooltipLoader.active = false;
        }
    }
}
