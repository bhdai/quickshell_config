import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root

    required property var activeWin
    required property Item anchorItem

    visible: true

    color: "transparent"

    implicitWidth: tooltipRect.width
    implicitHeight: tooltipRect.height

    anchor {
        window: anchorItem.QsWindow?.window
        item: anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: 8
    }

    Rectangle {
        id: tooltipRect
        width: contentColumn.implicitWidth + 24
        height: contentColumn.implicitHeight + 16

        color: "#222222"
        radius: 8
        border.color: "#555555"
        border.width: 1

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 8

            // header
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignLeft

                Text {
                    text: "󰖯"
                    color: "#ffffff"
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Window"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // full window title
            Text {
                text: activeWin ? (activeWin.title || "Untitled Window") : ""
                color: "#ffffff"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignLeft
                Layout.maximumWidth: 400
                wrapMode: Text.Wrap
            }
        }
    }
}
