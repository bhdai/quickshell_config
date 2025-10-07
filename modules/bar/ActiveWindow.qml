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
        color: "#444444"
        radius: 20
        margin: 5

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
    Loader {
        id: tooltipLoader
        active: root.containsMouse && root.isWinActiveOnWs
        sourceComponent: ActiveWindowTooltip {
            activeWin: root.activeWin
            anchorItem: root
        }
    }
}
