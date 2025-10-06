import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

WrapperRectangle {
    color: "#444444"
    radius: 20
    margin: 5

    leftMargin: 10
    rightMargin: 10

    readonly property var activeWin: Hyprland.activeToplevel
    readonly property var activeWs: Hyprland.focusedMonitor?.activeWorkspace
    readonly property bool isWinActiveOnWs: activeWin && activeWs && activeWin.workspace === activeWs

    readonly property var desktopEntry: isWinActiveOnWs ? DesktopEntries.heuristicLookup(activeWin.wayland?.appId || "") : null

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
            Layout.maximumWidth: 200
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
