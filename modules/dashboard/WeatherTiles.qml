import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import "dashboard_metrics.js" as Metrics
import "../../services/weather_format.js" as WeatherFormat

/**
 * Current conditions as six tiles in a 2x3 grid. Four are plain; UV and Sun are the two
 * where the shape encodes the reading, which is the only reason they get bespoke geometry.
 */
GridLayout {
    id: root

    columns: 2
    columnSpacing: Metrics.COL_GAP
    rowSpacing: Metrics.COL_GAP

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "device_thermostat"
        label: "Feels like"
        figure: WeatherFormat.formatTemperature(Weather.apparentTemperature)
        unit: "°"
        caption: WeatherFormat.apparentCaption(Weather.apparentTemperature, Weather.temperature)
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "humidity_percentage"
        label: "Humidity"
        figure: WeatherFormat.formatPercent(Weather.humidity)
        unit: "%"
        caption: WeatherFormat.humidityCaption(Weather.humidity)
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "air"
        label: "Wind"
        figure: WeatherFormat.formatSpeed(Weather.windSpeed)
        unit: "km/h"
        caption: WeatherFormat.windCaption(Weather.windDirection)

        // The needle is the tile's own reading of the bearing, so the direction is legible
        // without parsing the caption.
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            width: 26
            height: 26
            visible: Weather.hasData

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
                // A meteorological bearing is where the wind comes *from*, and QML's y
                // grows downward, so 0° must point down-screen for a northerly.
                rotation: Weather.windDirection
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
        figure: WeatherFormat.formatPrecipitation(Weather.precipitationSum)
        unit: "mm"
        caption: WeatherFormat.precipitationCaption(Weather.precipitationProbability)
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "wb_sunny"
        label: "UV index"
        figure: WeatherFormat.formatIndex(Weather.uvIndex)
        unit: ""
        caption: WeatherFormat.describeUv(Weather.uvIndex)

        // The eleven-point WHO scale as five dots: the lit run says which band today sits
        // in, which is the fact a bare "7" leaves you to look up.
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            spacing: 4
            visible: Weather.hasData

            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index
                    width: 7
                    height: 7
                    radius: 3.5
                    color: index < WeatherFormat.uvSteps(Weather.uvIndex) ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }
            }
        }
    }

    WeatherTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        symbol: "wb_twilight"
        label: "Sun"
        figure: ""
        unit: ""
        caption: WeatherFormat.formatClock(Weather.sunrise) + "  —  " + WeatherFormat.formatClock(Weather.sunset)

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
            visible: Weather.hasData

            // Elliptical, not circular: a semicircle wide enough to span the tile would be
            // 70px tall in a 50px gap and would climb out through the tile above it.
            readonly property real rx: (width - 8) / 2
            readonly property real ry: height - 5
            readonly property real cx: width / 2
            readonly property real cy: height
            readonly property real angle: Math.PI * (1 - WeatherFormat.dayProgress(Time.date, Weather.sunrise, Weather.sunset))

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
