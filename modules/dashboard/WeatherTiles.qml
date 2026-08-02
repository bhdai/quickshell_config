import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "dashboard_metrics.js" as Metrics
import "weather_tile_geometry.js" as TileGeometry
import "../../services/weather_format.js" as WeatherFormat

/**
 * Current conditions as six tiles in a 2x3 grid. Three are plain; humidity, UV and the sun
 * encode their reading in the tile's shape, which is the only reason they get bespoke
 * geometry — the number is still there to be read either way.
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
        // The dew point chip below occupies the caption's row and interprets the figure in
        // its place.
        caption: ""

        // The tile fills to the reading, so the number has a second, wordless statement of
        // itself; the wave is what stops a flat block from reading as a progress bar.
        backdrop: HumidityWave {
            anchors.fill: parent
            cornerRadius: Appearance.rounding.small
            color: Appearance.colors.colSecondaryContainer
            level: Weather.hasData ? TileGeometry.waterLevel(Weather.humidity) : 0
        }

        // Dew point rather than a "humid"/"dry" word: relative humidity alone does not say
        // how much water is actually in the air, and the dew point does.
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 5
            visible: Weather.hasData

            Rectangle {
                width: dewPoint.implicitWidth + 10
                height: dewPoint.implicitHeight + 4
                radius: height / 2
                color: Appearance.colors.colTertiaryContainer
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: dewPoint
                    anchors.centerIn: parent
                    text: WeatherFormat.formatTemperature(Weather.dewPoint) + "°"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnTertiaryContainer
                }
            }

            Text {
                text: "Dew point"
                anchors.verticalCenter: parent.verticalCenter
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }
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
        label: "Sunrise & sunset"
        figure: ""
        unit: ""
        // The two clock times are the footer below, laid out one per line with its own glyph.
        caption: ""

        // The ridge is the whole daylight span and the sun is now, so how much of the day is
        // left reads as a distance along it rather than as a subtraction of two clock times.
        // Full bleed, because the horizon has to cut the tile rather than sit in a box drawn
        // inside it — the times below read as standing on the ground that way.
        backdrop: SunPath {
            anchors.fill: parent
            cornerRadius: Appearance.rounding.small
            progress: WeatherFormat.dayProgress(Time.date, Weather.sunrise, Weather.sunset)
            visible: Weather.hasData
        }

        Column {
            id: times
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 1
            visible: Weather.hasData

            Row {
                spacing: 4

                MaterialSymbol {
                    text: "wb_sunny"
                    iconSize: 12
                    color: Appearance.colors.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: WeatherFormat.formatClock(Weather.sunrise)
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: 4

                MaterialSymbol {
                    text: "wb_twilight"
                    iconSize: 12
                    color: Appearance.colors.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: WeatherFormat.formatClock(Weather.sunset)
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
