import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout

/**
 * The month grid, always six rows so that navigating months cannot change the card's
 * height against the dashboard's fixed canvas.
 */
Rectangle {
    id: root

    property int monthShift: 0
    readonly property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    readonly property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)

    // What the card would be if nothing squeezed it, and the two things the geometry
    // fixture has to measure rather than infer: that the month is six rows and that the
    // Today control keeps its row while it is inactive.
    readonly property real naturalHeight: content.implicitHeight + 24
    readonly property Item weekGrid: grid
    readonly property Item todayControl: todayButton

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                onClicked: root.monthShift--
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(root.viewingDate, "MMMM yyyy")
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                horizontalAlignment: Text.AlignHCenter
            }

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                onClicked: root.monthShift++
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: CalendarLayout.weekDays
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.day
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        ColumnLayout {
            id: grid
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: 6
                delegate: RowLayout {
                    id: weekRow
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: 7
                        // The ripple is the whole interaction. A day cell has nothing
                        // downstream to select for, so it has no click handler and no
                        // selected state — only the acknowledgement that it was pressed.
                        delegate: RippleButton {
                            id: dayCell
                            required property int index
                            readonly property var dayData: root.calendarLayout[weekRow.index][index]
                            readonly property bool isToday: dayData.today === 1
                            readonly property bool isOtherMonth: dayData.today === -1

                            Layout.fillWidth: true
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.small
                            toggled: isToday

                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colBackgroundToggled: Appearance.colors.colPrimary
                            colBackgroundToggledHover: Appearance.colors.colPrimary

                            contentItem: Text {
                                text: dayCell.dayData.day
                                font.family: Appearance.font.family.main
                                font.pixelSize: 14
                                font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                                color: dayCell.isToday ? Appearance.m3colors.m3onPrimaryFixed : (dayCell.isOtherMonth ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }

        // Opacity-gated rather than visibility-gated: the row holds its space so that
        // navigating a month cannot move the grid above it. It also carries no top margin
        // — 4px there is exactly what put this column at 351 against the 347 the fixed
        // card has for it, leaving the ColumnLayout to compress something to fit.
        RippleButton {
            id: todayButton
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 80
            implicitHeight: 28
            buttonRadius: 14
            opacity: root.monthShift !== 0 ? 1 : 0
            enabled: root.monthShift !== 0
            colBackground: "transparent"
            onClicked: root.monthShift = 0
            contentItem: Text {
                text: "Today"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
