import QtQuick
import qs.modules.common
import "mock.js" as Mock

// #87's composition: a full-width band over `calendar | 2x3 tiles`.
Item {
    id: root

    property string headerVariant: "1"
    property int monthShift: 0
    readonly property real calendarNatural: calendar.naturalHeight

    WeatherHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Mock.HEADER_H
        variant: root.headerVariant
    }

    CalendarCard {
        id: calendar
        anchors.top: header.bottom
        anchors.topMargin: Mock.GAP
        anchors.left: parent.left
        width: Mock.COL_W
        height: Mock.BODY_H
        monthShift: root.monthShift
    }

    WeatherTiles {
        anchors.top: header.bottom
        anchors.topMargin: Mock.GAP
        anchors.right: parent.right
        width: Mock.COL_W
        height: Mock.BODY_H
    }
}
