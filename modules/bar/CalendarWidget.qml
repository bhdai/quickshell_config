import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout

Rectangle {
    id: root

    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var selectedDate: null

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

        // Large digital clock
        Text {
            text: Time.hoursMinutes
            font.pixelSize: 64
            font.weight: Font.Light
            color: Colors.text
            Layout.alignment: Qt.AlignHCenter
        }

        // Uptime display
        Text {
            text: "Uptime: " + Time.uptime
            font.pixelSize: 14
            color: Colors.subtext0
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.preferredHeight: 8 }

        // Calendar section
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: calendarContent.implicitHeight + 24
            color: Colors.surface
            radius: 12

            ColumnLayout {
                id: calendarContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Month/Year header with navigation
                RowLayout {
                    Layout.preferredWidth: 280  // Match calendar grid width (7 cols × 40px)
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        onClicked: root.monthShift--
                        contentItem: Item {
                            implicitWidth: 28
                            implicitHeight: 28
                            MaterialSymbol {
                                text: "chevron_left"
                                iconSize: 18
                                anchors.centerIn: parent
                            }
                        }
                    }

                    Text {
                        text: Qt.formatDate(root.viewingDate, "MMMM yyyy")
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Colors.text
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        onClicked: root.monthShift++
                        contentItem: Item {
                            implicitWidth: 28
                            implicitHeight: 28
                            MaterialSymbol {
                                text: "chevron_right"
                                iconSize: 18
                                anchors.centerIn: parent
                            }
                        }
                    }
                }

                // Weekday headers
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0

                    Repeater {
                        model: CalendarLayout.weekDays
                        delegate: Text {
                            text: modelData.day
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Colors.subtext0
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: 40
                        }
                    }
                }

                // Calendar grid (6 rows × 7 columns)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    Repeater {
                        model: 6
                        delegate: RowLayout {
                            id: weekRow
                            required property int index
                            property int rowIndex: index
                            Layout.fillWidth: true
                            spacing: 0

                            Repeater {
                                model: 7
                                delegate: RippleButton {
                                    id: dayButton
                                    required property int index
                                    property var dayData: root.calendarLayout[weekRow.rowIndex][index]
                                    property bool isToday: dayData.today === 1
                                    property bool isOtherMonth: dayData.today === -1

                                    implicitWidth: 40
                                    implicitHeight: 36
                                    buttonRadius: 8
                                    toggled: isToday

                                    colBackground: "transparent"
                                    colBackgroundHover: Colors.surfaceHover
                                    colBackgroundToggled: Colors.accent
                                    colBackgroundToggledHover: Colors.accent

                                    onClicked: {
                                        // Future: handle date selection
                                    }

                                    contentItem: Text {
                                        text: dayButton.dayData.day
                                        font.pixelSize: 14
                                        font.weight: dayButton.isToday ? Font.Bold : Font.Normal
                                        color: dayButton.isToday ? Colors.m3onPrimaryFixed : (dayButton.isOtherMonth ? Colors.subtext1 : Colors.text)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // Today button
                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    implicitWidth: 80
                    implicitHeight: 28
                    buttonRadius: 14
                    visible: root.monthShift !== 0
                    onClicked: root.monthShift = 0
                    contentItem: Text {
                        text: "Today"
                        font.pixelSize: 12
                        color: Colors.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
