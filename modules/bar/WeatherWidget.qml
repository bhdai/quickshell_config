import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    color: "transparent"
    implicitWidth: 380
    implicitHeight: contentLayout.implicitHeight + 32

    ColumnLayout {
        id: contentLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 16

        // Current weather header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: currentWeatherContent.implicitHeight + 24
            color: Colors.surface
            radius: 12

            ColumnLayout {
                id: currentWeatherContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Location and main temp
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialSymbol {
                        text: Weather.getWeatherIcon(Weather.currentData.weatherCode)
                        iconSize: 48
                        color: Colors.accent
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: Weather.currentData.city
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Colors.subtext0
                        }

                        Text {
                            text: Weather.currentData.temp
                            font.pixelSize: 36
                            font.weight: Font.Light
                            color: Colors.text
                        }

                        Text {
                            text: Weather.currentData.condition
                            font.pixelSize: 12
                            color: Colors.subtext0
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignTop

                        Text {
                            text: "Feels like " + Weather.currentData.feelsLike
                            font.pixelSize: 12
                            color: Colors.subtext0
                        }
                    }
                }
            }
        }

        // Hourly forecast
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hourlyContent.implicitHeight + 24
            color: Colors.surface
            radius: 12

            ColumnLayout {
                id: hourlyContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "Hourly Forecast"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.subtext0
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    RowLayout {
                        spacing: 16

                        Repeater {
                            model: Weather.hourlyForecast
                            delegate: ColumnLayout {
                                spacing: 4

                                Text {
                                    text: modelData.time
                                    font.pixelSize: 11
                                    color: Colors.subtext0
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 24
                                    color: Colors.text
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.temp
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: Colors.text
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // Current stats (humidity, wind)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statsContent.implicitHeight + 24
            color: Colors.surface
            radius: 12

            RowLayout {
                id: statsContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 24

                // Humidity
                RowLayout {
                    spacing: 8

                    MaterialSymbol {
                        text: "humidity_percentage"
                        iconSize: 24
                        color: Colors.accent
                    }

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Humidity"
                            font.pixelSize: 11
                            color: Colors.subtext0
                        }
                        Text {
                            text: Weather.currentData.humidity
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Colors.text
                        }
                    }
                }

                // Wind
                RowLayout {
                    spacing: 8

                    MaterialSymbol {
                        text: "air"
                        iconSize: 24
                        color: Colors.accent
                    }

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Wind"
                            font.pixelSize: 11
                            color: Colors.subtext0
                        }
                        Text {
                            text: Weather.currentData.wind + " " + Weather.currentData.windDir
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Colors.text
                        }
                    }
                }
            }
        }

        // Weekly forecast
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: weeklyContent.implicitHeight + 24
            color: Colors.surface
            radius: 12

            ColumnLayout {
                id: weeklyContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "7-Day Forecast"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.subtext0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: Weather.weeklyForecast
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: modelData.day
                                font.pixelSize: 13
                                color: Colors.text
                                Layout.preferredWidth: 50
                            }

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 20
                                color: Colors.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: modelData.high
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Colors.text
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 35
                            }

                            Text {
                                text: modelData.low
                                font.pixelSize: 13
                                color: Colors.subtext0
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 35
                            }
                        }
                    }
                }
            }
        }
    }
}
