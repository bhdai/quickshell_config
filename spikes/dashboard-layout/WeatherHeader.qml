import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "mock.js" as Mock

// #87 fixed that the band is full width and 72px and handed the treatment here. All three
// variants keep those two numbers and disagree only about hierarchy inside them.
Item {
    id: root

    property string variant: "1"

    readonly property date now: new Date()

    Rectangle {
        anchors.fill: parent
        visible: root.variant === "2"
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.small
    }

    Item {
        anchors.fill: parent
        // The card variant needs its content inset from the fill; the bare ones sit flush
        // with the columns below so the date lines up with the calendar's left edge.
        anchors.leftMargin: root.variant === "2" ? 14 : 2
        anchors.rightMargin: root.variant === "2" ? 14 : 2

        Column {
            id: dateBlock
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: Qt.formatDate(root.now, root.variant === "3" ? "ddd d MMM" : "dddd, d MMMM")
                font.family: Appearance.font.family.main
                font.pixelSize: root.variant === "3" ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.huge
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            Text {
                visible: root.variant !== "3"
                text: "week " + Math.ceil(((root.now - new Date(root.now.getFullYear(), 0, 1)) / 86400000 + 1) / 7)
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.variant === "3" ? 10 : 8

            CustomIcon {
                source: "weather/" + Mock.WEATHER.icon
                width: root.variant === "3" ? 48 : 38
                height: width
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: String(Mock.WEATHER.temp)
                    font.family: Appearance.font.family.main
                    font.pixelSize: root.variant === "3" ? 42 : 34
                    font.weight: Font.Normal
                    color: Appearance.colors.colOnLayer0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "°"
                    font.family: Appearance.font.family.main
                    font.pixelSize: root.variant === "3" ? 42 : 34
                    color: Appearance.colors.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Mock.WEATHER.condition
                    font.family: Appearance.font.family.main
                    font.pixelSize: root.variant === "3" ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }

                Text {
                    text: "H:" + Mock.WEATHER.high + "°  L:" + Mock.WEATHER.low + "°"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
