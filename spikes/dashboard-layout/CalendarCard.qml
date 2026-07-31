import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout

// The calendar column, re-housed into #87's 332px column. calendar_layout.js is the real
// one, symlinked in by stage.sh — a spike that re-derived the month grid would be
// measuring its own arithmetic instead of the layout.
Rectangle {
    id: root

    property int monthShift: 0
    readonly property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    readonly property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)

    // What the card would be if nothing squeezed it. capture.sh logs this against #87's
    // 347 to find out whether the derived body height was actually big enough.
    readonly property real naturalHeight: content.implicitHeight + 24

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
                        delegate: Item {
                            id: cell
                            required property int index
                            readonly property var dayData: root.calendarLayout[weekRow.index][index]
                            readonly property bool isToday: dayData.today === 1
                            readonly property bool isOtherMonth: dayData.today === -1

                            Layout.fillWidth: true
                            implicitHeight: 36

                            // Drawn as its own rectangle rather than as RippleButton's
                            // `toggled` background, which is invisible to an offscreen
                            // grab: that background is masked by a Qt5Compat OpacityMask
                            // layer effect, and a layer.effect subtree renders nothing
                            // under QT_QPA_PLATFORM=offscreen. A capture that dropped the
                            // one filled cell in the month would misreport the layout.
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: cell.isToday ? Appearance.colors.colPrimary : "transparent"
                            }

                            RippleButton {
                                anchors.fill: parent
                                buttonRadius: Appearance.rounding.small
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover

                                contentItem: Text {
                                    text: cell.dayData.day
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 14
                                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                                    color: cell.isToday ? Appearance.m3colors.m3onPrimaryFixed : (cell.isOtherMonth ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // Opacity-gated rather than visible-gated, per #87: the row holds its space so
        // navigating a month cannot change the column's height against a fixed canvas.
        //
        // No top margin, unlike the widget this came from. The current CalendarWidget adds
        // 4 here, which is precisely what put the column at 351 against #87's 347 budget
        // and left the ColumnLayout quietly compressing something to fit. Dropping it
        // makes 700 x 507 exact.
        RippleButton {
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
