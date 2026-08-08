import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../services/weather_format.js" as WeatherFormat

/**
 * The full-width band: what day it is on the left, what it is doing outside on the right.
 * Filled in the same card grammar as the calendar and tiles below, so the pane reads as
 * one composition rather than a banner over a card.
 */
Item {
    id: root

    readonly property date now: Time.date

    // The two clusters the band anchors to opposite edges. Neither is width-constrained and
    // nothing clips them, so a band too narrow for both would draw one over the other; only
    // measuring the gap between them catches it.
    readonly property Item dateCluster: date
    readonly property Item readingCluster: reading

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.small
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        Column {
            id: date
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: Qt.formatDate(root.now, "dddd, d MMMM")
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            Text {
                text: "week " + Math.ceil(((root.now - new Date(root.now.getFullYear(), 0, 1)) / 86400000 + 1) / 7)
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        Row {
            id: reading
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            CustomIcon {
                // Held in the layout while there is nothing to draw, so the first reading
                // does not shift the row it arrives into.
                opacity: Weather.hasData ? 1 : 0
                source: "weather/" + WeatherFormat.iconFor(Weather.weatherCode, Weather.isDay ? 1 : 0)
                width: 38
                height: width
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: WeatherFormat.formatTemperature(Weather.temperature)
                    font.family: Appearance.font.family.main
                    font.pixelSize: 34
                    color: Appearance.colors.colOnLayer0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "°"
                    font.family: Appearance.font.family.main
                    font.pixelSize: 34
                    color: Appearance.colors.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Weather.hasData ? WeatherFormat.describeCode(Weather.weatherCode) : WeatherFormat.PLACEHOLDER
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }

                Text {
                    text: "H:" + WeatherFormat.formatTemperature(Weather.high) + "°  L:" + WeatherFormat.formatTemperature(Weather.low) + "°"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                // Stale readings stay on screen; this is the only thing that stops them
                // reading as live. It appears at an hour old and says nothing before that.
                Text {
                    text: WeatherFormat.staleNotice(Weather.lastUpdated.getTime(), root.now.getTime())
                    visible: text !== ""
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
