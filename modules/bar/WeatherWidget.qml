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
    implicitWidth: 600
    // Height fits content
    implicitHeight: contentLayout.implicitHeight + 40

    function formatTemp(tempStr) {
        if (!tempStr || tempStr === "--")
            return "--";
        // tempStr is like "20°C"
        return parseInt(tempStr) + "°";
    }

    function formatTime(timeStr) {
        if (!timeStr)
            return "";
        // timeStr is "15:00"
        let parts = timeStr.split(":");
        let hour = parseInt(parts[0]);
        let ampm = hour >= 12 ? "PM" : "AM";
        hour = hour % 12;
        hour = hour ? hour : 12; // the hour '0' should be '12'
        return hour + " " + ampm;
    }

    function formatCurrentTime() {
        return Qt.formatDateTime(new Date(), "h AP"); // e.g. "12 PM"
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // 1. Header Section: Condition + Location
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: Weather.currentData.condition || "Loading..."
                font.pixelSize: 24
                font.weight: Font.Bold
                color: Colors.text
            }
            Text {
                text: Weather.currentData.city
                font.pixelSize: 14
                color: Colors.subtext0
            }
        }

        // 2. Hourly Forecast Section
        // Layout: "Now" (Large) + ScrollView/Row of others
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // "Now" Item (Emphasized)
            ColumnLayout {
                Layout.preferredWidth: (contentLayout.width) / 8
                Layout.alignment: Qt.AlignBottom
                spacing: 8

                Text {
                    text: root.formatCurrentTime()
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Colors.text
                    Layout.alignment: Qt.AlignHCenter
                }

                CustomIcon {
                    source: "weather/" + Weather.getWeatherIcon(Weather.currentData.weatherCode, Weather.currentData.isDay)
                    width: 64
                    height: 64
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.formatTemp(Weather.currentData.temp)
                    font.pixelSize: 48
                    font.weight: Font.Bold
                    color: Colors.text
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // The rest of the hours
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: Weather.hourlyForecast
                    delegate: ColumnLayout {
                        Layout.preferredWidth: (contentLayout.width) / 8
                        Layout.alignment: Qt.AlignBottom
                        spacing: 12

                        Text {
                            text: root.formatTime(modelData.time)
                            font.pixelSize: 12
                            color: Colors.subtext0
                            Layout.alignment: Qt.AlignHCenter
                        }

                        CustomIcon {
                            source: "weather/" + modelData.icon
                            width: 28
                            height: 28
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.formatTemp(modelData.temp)
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: Colors.text
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // 3. Stats Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: "Humidity: " + Weather.currentData.humidity
                font.pixelSize: 12
                color: Colors.subtext0
            }
            Text {
                text: "Wind: " + Weather.currentData.wind + " " + (Weather.currentData.windDir || "")
                font.pixelSize: 12
                color: Colors.subtext0
            }
            Item {
                Layout.fillWidth: true
            } // Spacer
        }

        // 4. Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.outline
            opacity: 0.5
        }

        // 5. Weekly Forecast Section (Horizontal)
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Weather.weeklyForecast
                delegate: ColumnLayout {
                    Layout.preferredWidth: (contentLayout.width) / 8
                    spacing: 6

                    Text {
                        text: modelData.day
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Colors.text
                        Layout.alignment: Qt.AlignHCenter
                    }

                    CustomIcon {
                        source: "weather/" + modelData.icon
                        width: 24
                        height: 24
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.formatTemp(modelData.high)
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Colors.text
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.formatTemp(modelData.low)
                        font.pixelSize: 12
                        color: Colors.subtext0
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
