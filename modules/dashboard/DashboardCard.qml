import QtQuick
import qs.modules.common
import "dashboard_metrics.js" as Metrics

/**
 * The dashboard's fixed card: a tab bar over one pane. Split from the window so it can be
 * measured offscreen, where no layer surface can be built.
 *
 * Nothing here is sized by its content. A pane that does not fit should be seen not
 * fitting rather than quietly growing the canvas.
 */
Rectangle {
    id: root

    property var tabs: ["Calendar"]
    property string currentTab: "calendar"
    // What the pane loader built, for the offscreen geometry fixture to measure.
    readonly property Item paneItem: paneLoader.item

    signal tabSelected(string tab)

    implicitWidth: Metrics.CARD_W
    implicitHeight: Metrics.CARD_H

    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.large
    border.color: Appearance.colors.colOutlineVariant
    border.width: 1

    DashTabBar {
        id: tabBar
        anchors.top: parent.top
        anchors.topMargin: Metrics.PAD
        anchors.left: parent.left
        anchors.leftMargin: Metrics.PAD
        anchors.right: parent.right
        anchors.rightMargin: Metrics.PAD
        tabs: root.tabs
        current: root.currentTab
        onSelected: tab => root.tabSelected(tab)
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.topMargin: Metrics.GAP
        anchors.left: parent.left
        anchors.leftMargin: Metrics.PAD
        width: Metrics.PANE_W
        height: Metrics.PANE_H

        // One property, one Loader, inactive destinations unloaded — so opening the
        // calendar builds nothing a later tab owns, and leaving one releases it.
        Loader {
            id: paneLoader
            anchors.fill: parent
            sourceComponent: root.currentTab === "calendar" ? calendarComponent : null

            opacity: 0
            Component.onCompleted: opacity = 1
            onSourceComponentChanged: {
                opacity = 0;
                opacity = 1;
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Metrics.TAB_FADE_MS
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    Component {
        id: calendarComponent
        CalendarPane {}
    }
}
