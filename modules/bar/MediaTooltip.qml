import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

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

        color: "#222222"
        radius: 8
        border.color: "#555555"
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
                    color: "#ffffff"
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Media"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // track title
            Text {
                text: activePlayer ? cleanTitleFunc(activePlayer.trackTitle) : "Unknown Title"
                color: "#ffffff"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignLeft
                Layout.maximumWidth: 300
                wrapMode: Text.Wrap
            }

            // artist
            Text {
                text: activePlayer ? (activePlayer.trackArtist || "Unknown Artist") : ""
                color: "#aaaaaa"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignLeft
                Layout.maximumWidth: 300
                wrapMode: Text.Wrap
            }
        }
    }
}
