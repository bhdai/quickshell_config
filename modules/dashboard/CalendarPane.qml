import QtQuick
import "dashboard_metrics.js" as Metrics

// A full-width date and weather band over `calendar | 2x3 weather tiles`. The two columns are
// not equal: the tile column is whatever six square tiles need, and the calendar keeps the
// rest.
Item {
    id: root

    // The calendar owns which month it is showing; this is the seam the geometry fixture
    // navigates through.
    property alias monthShift: calendar.monthShift
    // The three parts of the composition, for the offscreen geometry fixture. What it has
    // to measure is that the band is full width, that the two columns sit side by side, that
    // the tiles come out square, and that the calendar's natural height is not larger than
    // the fixed body it is given — a taller one means the ColumnLayout is quietly
    // compressing a row.
    readonly property Item band: header
    readonly property Item calendarColumn: calendar
    readonly property Item tileColumn: tiles

    implicitWidth: Metrics.CANVAS.calendar.width
    implicitHeight: Metrics.CANVAS.calendar.height

    WeatherHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Metrics.HEADER_H
    }

    CalendarCard {
        id: calendar
        anchors.top: header.bottom
        anchors.topMargin: Metrics.GAP
        anchors.left: parent.left
        width: Metrics.CALENDAR_COL_W
        height: Metrics.BODY_H
    }

    WeatherTiles {
        id: tiles
        anchors.top: header.bottom
        anchors.topMargin: Metrics.GAP
        anchors.right: parent.right
        width: Metrics.TILE_COL_W
        height: Metrics.BODY_H
    }
}
