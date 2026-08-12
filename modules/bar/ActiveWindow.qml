import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    implicitWidth: mainRow.implicitWidth
    implicitHeight: mainRow.implicitHeight

    // Core window state
    readonly property var activeWin: Hyprland.activeToplevel
    readonly property var activeWs: Hyprland.focusedMonitor?.activeWorkspace
    readonly property bool isWinActiveOnWs: activeWin && activeWs && activeWin?.workspace === activeWs

    // Workspace window list computation
    readonly property var workspaceToplevels: activeWs?.toplevels?.values || []
    readonly property var visibleWindows: {
        // slice() creates new array instance for QML reactivity
        let windows = workspaceToplevels.slice();

        // Ensure focused window is first if it exists in workspace
        if (isWinActiveOnWs && activeWin) {
            windows = windows.filter(w => w.address !== activeWin.address);
            windows.unshift(activeWin);
        }

        return windows.slice(0, 5); // Take max 5
    }
    readonly property int overflowCount: Math.max(0, workspaceToplevels.length - 5)

    // Main RowLayout for multi-window pill display
    RowLayout {
        id: mainRow
        spacing: 6

        // Handle empty workspace state - show "Desktop" text
        WrapperRectangle {
            visible: visibleWindows.length === 0
            color: Appearance.colors.colLayer1
            radius: 20
            margin: 5
            leftMargin: 10
            rightMargin: 10

            Text {
                text: "Desktop"
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 12
            }
        }

        // Window pill repeater - each window gets its own pill
        Repeater {
            model: visibleWindows

            delegate: MouseArea {
                id: windowPillArea
                implicitWidth: windowPill.implicitWidth
                implicitHeight: windowPill.implicitHeight
                hoverEnabled: true

                property var window: modelData
                property var entry: DesktopEntries.heuristicLookup(window.wayland?.appId || "")
                property bool isFocused: window.address === activeWin?.address

                onClicked: {
                    // Validate address before focusing
                    if (window.address && window.address.length > 0) {
                        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${window.address}" })`);
                    }
                }

                WrapperRectangle {
                    id: windowPill
                    color: windowPillArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1
                    radius: 20
                    margin: 5
                    leftMargin: 8
                    rightMargin: 8

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }

                    // Smooth width transition when title appears/disappears
                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.InOutCubic
                        }
                    }

                    RowLayout {
                        spacing: 6

                        IconImage {
                            implicitSize: 20
                            source: windowPillArea.entry?.icon ? Quickshell.iconPath(windowPillArea.entry.icon, true) : ""
                            Layout.alignment: Qt.AlignVCenter

                            // Fallback icon when no desktop entry icon
                            Text {
                                anchors.centerIn: parent
                                visible: !windowPillArea.entry?.icon
                                text: "󰖯"
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: 18
                            }
                        }

                        // Title only shown for focused window
                        Text {
                            visible: windowPillArea.isFocused
                            text: windowPillArea.window.title || "Untitled"
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            // Dynamic width: 300px base, -30px per window, min 150px
                            Layout.maximumWidth: Math.max(150, 300 - (visibleWindows.length * 30))
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // The pill elides the title it shows, so the tooltip's whole job is the full
                // one. Plain rather than rich: a title is a label, not the longer explanatory
                // text M3 reserves the rich variant for.
                Tooltip {
                    target: windowPillArea
                    side: Tooltip.Side.Below
                    text: windowPillArea.window ? (windowPillArea.window.title || "Untitled Window") : ""
                }
            }
        }

        // Overflow indicator with tooltip
        MouseArea {
            id: overflowArea
            visible: overflowCount > 0
            implicitWidth: overflowText.implicitWidth + 8
            implicitHeight: overflowText.implicitHeight + 8
            hoverEnabled: true

            Text {
                id: overflowText
                anchors.centerIn: parent
                text: "+" + overflowCount
                color: Appearance.colors.colSubtext
                font.pixelSize: 11
            }

            Tooltip {
                target: overflowArea
                side: Tooltip.Side.Below
                text: overflowCount + " more window" + (overflowCount > 1 ? "s" : "")
            }
        }
    }
}
