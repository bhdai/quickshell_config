import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.common
import "mock.js" as Mock

// #84's six tiles in a 2x3 grid. Four are plain; UV and Sun are the two where shape
// encodes data, which is the only reason they are allowed bespoke geometry.
GridLayout {
    id: root

    columns: 2
    columnSpacing: 12
    rowSpacing: 12

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "device_thermostat"
        label: "Feels like"
        figure: String(Mock.WEATHER.apparent)
        unit: "°"
        caption: (Mock.WEATHER.apparent - Mock.WEATHER.temp) + "° warmer"
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "humidity_percentage"
        label: "Humidity"
        figure: String(Mock.WEATHER.humidity)
        unit: "%"
        caption: "very humid"
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "air"
        label: "Wind"
        figure: String(Mock.WEATHER.windSpeed)
        unit: "km/h"
        caption: "from " + Mock.WEATHER.windCompass + " · " + Mock.WEATHER.windDeg + "°"

        // The compass needle is the tile's own reading of windDeg, so the direction is
        // legible at a glance without parsing the caption.
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            width: 26
            height: 26

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // Meteorological "from" bearing, and QML's y grows downward, so 0° must
                // point down-screen for a north wind arriving from the north.
                rotation: Mock.WEATHER.windDeg
                ShapePath {
                    strokeWidth: 2
                    strokeColor: Appearance.colors.colPrimary
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: 13
                    startY: 5
                    PathLine {
                        x: 13
                        y: 21
                    }
                }
            }
        }
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "rainy"
        label: "Precipitation"
        figure: Mock.WEATHER.precipMm.toFixed(1)
        unit: "mm"
        caption: Mock.WEATHER.precipChance + "% chance"
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "wb_sunny"
        label: "UV index"
        figure: String(Mock.WEATHER.uv)
        unit: ""
        caption: "high"

        // Eleven-point WHO scale compressed to five dots: the lit run shows where today
        // sits, which is the fact a bare "7" leaves you to look up.
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            spacing: 4

            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index
                    width: 7
                    height: 7
                    radius: 3.5
                    color: index < Math.round(Mock.WEATHER.uv / 11 * 5) ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }
            }
        }
    }

    WeatherTile {
        id: sunTile
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "wb_twilight"
        label: "Sun"
        figure: ""
        unit: ""
        caption: Mock.WEATHER.sunrise + "  —  " + Mock.WEATHER.sunset

        // The arc is the daylight span and the dot is now, so how much of the day is left
        // reads as a distance rather than as a subtraction of two clock times.
        Item {
            id: arcBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            // Clear of the caption below, which carries the two clock times.
            anchors.bottomMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 22

            // Elliptical, not circular: a semicircle wide enough to span the tile would be
            // 70px tall in a 50px gap and would climb out through the tile above it.
            readonly property real rx: (width - 8) / 2
            readonly property real ry: height - 5
            readonly property real cx: width / 2
            readonly property real cy: height
            readonly property real angle: Math.PI * (1 - Mock.WEATHER.dayProgress)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 2
                    strokeColor: Appearance.colors.colPrimary
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: arcBox.cx - arcBox.rx
                    startY: arcBox.cy
                    PathArc {
                        x: arcBox.cx + arcBox.rx
                        y: arcBox.cy
                        radiusX: arcBox.rx
                        radiusY: arcBox.ry
                        useLargeArc: false
                        direction: PathArc.Clockwise
                    }
                }
            }

            Rectangle {
                width: 9
                height: 9
                radius: 4.5
                color: Appearance.colors.colPrimary
                x: arcBox.cx + arcBox.rx * Math.cos(arcBox.angle) - width / 2
                y: arcBox.cy - arcBox.ry * Math.sin(arcBox.angle) - height / 2
            }
        }
    }
}
