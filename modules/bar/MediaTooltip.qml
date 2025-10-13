import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common

PopupWindow {
    id: root

    required property var activePlayer
    required property Item anchorItem
    required property var cleanTitleFunc

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

        color: Colors.background
        radius: 8
        border.color: Colors.overlay0
        border.width: 1

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 8

            // header with music icon
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignLeft

                Text {
                    text: "󰎇"
                    color: Colors.text
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Media"
                    color: Colors.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // track title
            Text {
                text: activePlayer ? cleanTitleFunc(activePlayer.trackTitle) : "Unknown Title"
                color: Colors.text
                font.pixelSize: 12
                Layout.alignment: Qt.AlignLeft
                Layout.maximumWidth: 300
                wrapMode: Text.Wrap
            }

            // artist
            Text {
                text: activePlayer ? (activePlayer.trackArtist || "Unknown Artist") : ""
                color: Colors.subtext1
                font.pixelSize: 11
                Layout.alignment: Qt.AlignLeft
                Layout.maximumWidth: 300
                wrapMode: Text.Wrap
            }
        }
    }
}
