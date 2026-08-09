import QtQuick
import qs.modules.common
import "dashboard_metrics.js" as Metrics

/**
 * The dashboard's card: a tab bar over one pane. Split from the window so it can be measured
 * offscreen, where no layer surface can be built.
 *
 * The card is chrome and nothing else. Each destination names the canvas it wants as its
 * pane's implicit size, and the card — and through it the window — is that plus the padding,
 * the tab bar and the gap. Nothing is sized by its content: a pane that does not fit the size
 * its own tab asked for should be seen not fitting rather than quietly growing the window.
 */
Rectangle {
    id: root

    required property var tabs
    required property string currentTab
    // What the pane loader built and the row above it, for the offscreen geometry fixture
    // to measure.
    readonly property Item paneItem: paneLoader.item
    readonly property Item tabBarItem: tabBar
    readonly property bool activeTabFocused: tabBar.activeTabFocused

    signal tabSelected(string tab)

    // The width the card is travelling to, published ahead of the Behavior that takes
    // `implicitWidth` there. Anything that has to place itself against the destination the
    // card is arriving at — rather than the width it happens to be passing through this
    // frame — reads this instead.
    readonly property real settledWidth: Metrics.cardWidth(paneLoader.implicitWidth)

    implicitWidth: root.settledWidth
    implicitHeight: Metrics.cardHeight(paneLoader.implicitHeight)

    // The card is destroyed and rebuilt every time the dashboard opens, so the first size is
    // not a resize. Without this every open would animate up from nothing.
    property bool placed: false
    Component.onCompleted: Qt.callLater(() => root.placed = true)

    // One animation for the whole move, here rather than in the window above or the panes
    // below: two of them animating the same change reads as a single sluggish resize with a
    // soft landing.
    Behavior on implicitWidth {
        enabled: root.placed
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.placed
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

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
        // The bar is anchored to both of the card's padded edges, so its settled width is the
        // card's settled width less that padding.
        settledBarWidth: root.settledWidth - 2 * Metrics.PAD
        gridFocusTarget: root.currentTab === "wallpaper" ? paneLoader.item : null
        onSelected: tab => root.tabSelected(tab)
    }

    // The card is still travelling to the new size while the pane inside it is already at
    // one, so the pane has to be revealed and hidden by the card's edge rather than stretched
    // through whatever width the card is passing through.
    Item {
        anchors.top: tabBar.bottom
        anchors.topMargin: Metrics.GAP
        anchors.left: parent.left
        anchors.leftMargin: Metrics.PAD
        anchors.right: parent.right
        anchors.rightMargin: Metrics.PAD
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Metrics.PAD
        clip: true

        // One property, one Loader, inactive destinations unloaded — so opening the dashboard
        // builds nothing a later tab owns, and leaving one releases it.
        //
        // Anchored to a corner rather than filled: the pane names its own size, and a filled
        // loader would hand it the card's animating one instead.
        Loader {
            id: paneLoader
            anchors.top: parent.top
            anchors.left: parent.left
            sourceComponent: {
                switch (root.currentTab) {
                case "dashboard":
                    return dashboardComponent;
                case "wallpaper":
                    return wallpaperComponent;
                }
                return null;
            }

            opacity: 0
            Component.onCompleted: opacity = 1
            // The reset has to be a cut and only the arrival a fade. Assigning 0 and then 1
            // through a live Behavior is not that: the second assignment retargets the first
            // before a frame has advanced, so the animation runs 1 to 1 and the pane appears
            // at full opacity in a card that is still resizing under it.
            onSourceComponentChanged: {
                fade.enabled = false;
                opacity = 0;
                fade.enabled = true;
                opacity = 1;
            }
            Behavior on opacity {
                id: fade
                NumberAnimation {
                    duration: Metrics.TAB_FADE_MS
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    Component {
        id: dashboardComponent
        DashboardPane {}
    }

    Component {
        id: wallpaperComponent
        WallpaperPane {
            tabTarget: tabBar
        }
    }
}
