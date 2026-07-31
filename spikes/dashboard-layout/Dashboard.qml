import QtQuick
import qs.modules.common
import "mock.js" as Mock

// The card itself, at #87's fixed 700x507. Nothing here resizes: if a variant does not
// fit, it should be seen not fitting rather than quietly growing the canvas.
Rectangle {
    id: root

    property string currentTab: "calendar"
    property var grid: Mock.GRIDS[0]
    property string headerVariant: "1"
    // Drives the capture run's six-week month; in interactive use the card's own arrows
    // move it and this stays where they left it.
    property int monthShift: 0
    // What the calendar column would take if the layout did not squeeze it. Read by
    // shell.qml's measurement log against #87's derived 347.
    readonly property real calendarNatural: calendarPane.calendarNatural

    implicitWidth: Mock.CARD_W
    implicitHeight: Mock.CARD_H

    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.large

    DashTabBar {
        id: tabBar
        anchors.top: parent.top
        anchors.topMargin: Mock.PAD
        anchors.left: parent.left
        anchors.leftMargin: Mock.PAD
        anchors.right: parent.right
        anchors.rightMargin: Mock.PAD
        current: root.currentTab
        onSelected: tab => root.currentTab = tab
    }

    Item {
        id: pane
        anchors.top: tabBar.bottom
        anchors.topMargin: Mock.GAP
        anchors.left: parent.left
        anchors.leftMargin: Mock.PAD
        width: Mock.PANE_W
        height: Mock.PANE_H

        // One property, one Loader, inactive tab destroyed — #87 section 7. The fade is
        // the spike's proposal for the transition the ticket asks about; it is a property
        // on the Loader, so "no transition at all" is this number set to 0.
        Loader {
            id: paneLoader
            anchors.fill: parent
            sourceComponent: root.currentTab === "wallpaper" ? wallpaperComp : calendarComp

            opacity: 0
            Component.onCompleted: opacity = 1
            onSourceComponentChanged: {
                opacity = 0;
                opacity = 1;
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    Component {
        id: calendarComp
        CalendarPane {
            headerVariant: root.headerVariant
            monthShift: root.monthShift
        }
    }

    Component {
        id: wallpaperComp
        WallpaperPane {
            grid: root.grid
        }
    }

    // Measured off-screen so the log always has a calendar to measure even while the
    // wallpaper tab is the one on show.
    CalendarPane {
        id: calendarPane
        visible: false
        width: Mock.PANE_W
        height: Mock.PANE_H
        headerVariant: root.headerVariant
    }
}
