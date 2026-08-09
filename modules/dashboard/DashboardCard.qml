import QtQuick
import qs.modules.common
import "dashboard_metrics.js" as Metrics

/**
 * The Dashboard's clipped card and its destination track. A destination change first makes
 * the complete swept corridor resident, then moves the fixed-size pane segments and card on
 * the same clock. Only the selected pane survives a confirmed final settle.
 */
Rectangle {
    id: root

    required property var tabs
    required property string currentTab

    readonly property Item paneItem: transitionState.segmentFor(root.currentTab)?.paneItem ?? null
    readonly property Item tabBarItem: tabBar
    readonly property Item indicatorItem: tabBar.indicatorItem
    readonly property bool activeTabFocused: tabBar.activeTabFocused
    readonly property bool transitionMotionRunning: trackMotion.running
    readonly property real transitionTrackPosition: track.x
    readonly property real targetTrackPosition: -Metrics.TRACK_START[transitionState.destination]
    readonly property var residentDestinationKeys: {
        const resident = [];
        for (let i = 0; i < paneRepeater.count; i++) {
            const segment = paneRepeater.itemAt(i);
            if (segment?.paneItem)
                resident.push(segment.destinationKey);
        }
        return resident;
    }

    // The card is rebuilt on every open, so its first geometry is placement rather than a
    // destination transition.
    property bool placed: false
    signal tabSelected(string tab)

    // The tab indicator needs the destination width before the card's Behavior starts moving.
    readonly property real settledWidth: Metrics.cardWidth(Metrics.CANVAS[transitionState.destination].width)

    implicitWidth: root.settledWidth
    implicitHeight: Metrics.cardHeight(Metrics.CANVAS[transitionState.destination].height)

    Component.onCompleted: {
        transitionState.requestedKeys = [root.currentTab];
        transitionState.destination = root.currentTab;
        Qt.callLater(() => root.placed = true);
    }

    onCurrentTabChanged: {
        if (root.placed)
            transitionState.prepare(root.currentTab);
        else {
            transitionState.requestedKeys = [root.currentTab];
            transitionState.destination = root.currentTab;
        }
    }
    onTransitionMotionRunningChanged: transitionState.pruneIfSettled()

    QtObject {
        id: transitionState

        property string destination: root.currentTab
        property var requestedKeys: [root.currentTab]

        function segmentFor(key: string): Item {
            for (let i = 0; i < paneRepeater.count; i++) {
                const segment = paneRepeater.itemAt(i);
                if (segment?.destinationKey === key)
                    return segment;
            }
            return null;
        }

        function componentFor(key: string): Component {
            switch (key) {
            case "dashboard":
                return dashboardComponent;
            case "wallpaper":
                return wallpaperComponent;
            case "performance":
                return performanceComponent;
            }
            return null;
        }

        function prepare(destination: string): void {
            const from = root.tabs.findIndex(tab => tab.key === transitionState.destination);
            const to = root.tabs.findIndex(tab => tab.key === destination);
            if (from < 0 || to < 0)
                return;

            const requested = new Set(transitionState.requestedKeys);
            for (let i = Math.min(from, to); i <= Math.max(from, to); i++)
                requested.add(root.tabs[i].key);
            transitionState.requestedKeys = root.tabs.filter(tab => requested.has(tab.key)).map(tab => tab.key);
            transitionState.commit(destination);
        }

        function commit(destination: string): void {
            if (root.currentTab !== destination)
                return;
            for (const key of transitionState.requestedKeys) {
                if (!transitionState.segmentFor(key)?.paneItem) {
                    Qt.callLater(() => transitionState.commit(destination));
                    return;
                }
            }
            transitionState.destination = destination;
        }

        function pruneIfSettled(): void {
            if (root.transitionMotionRunning
                    || root.transitionTrackPosition !== root.targetTrackPosition
                    || transitionState.destination !== root.currentTab)
                return;
            transitionState.requestedKeys = [transitionState.destination];
        }
    }

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
        settledBarWidth: root.settledWidth - 2 * Metrics.PAD
        gridFocusTarget: root.currentTab === "wallpaper" ? root.paneItem : null
        onSelected: tab => root.tabSelected(tab)
    }

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

        Item {
            id: track

            x: root.targetTrackPosition
            width: Metrics.TRACK_W
            height: Math.max(...Object.values(Metrics.CANVAS).map(canvas => canvas.height))

            Behavior on x {
                enabled: root.placed
                NumberAnimation {
                    id: trackMotion
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Repeater {
                id: paneRepeater
                model: root.tabs

                delegate: Item {
                    id: segment

                    required property var modelData
                    readonly property string destinationKey: modelData.key
                    readonly property alias paneItem: paneLoader.item

                    x: Metrics.TRACK_START[segment.destinationKey]
                    width: Metrics.CANVAS[segment.destinationKey].width
                    height: Metrics.CANVAS[segment.destinationKey].height

                    Loader {
                        id: paneLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        active: transitionState.requestedKeys.includes(segment.destinationKey)
                        sourceComponent: transitionState.componentFor(segment.destinationKey)
                    }
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

    Component {
        id: performanceComponent
        PerformancePane {}
    }
}
