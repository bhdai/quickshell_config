import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "dashboard_metrics.js" as Metrics

/**
 * Material 3 primary tabs: equal-width, label-only, with the indicator hugging the
 * rendered label rather than the cell. Each tab carries a stable key separately from its
 * presentation label, and the signal carries that key.
 */
Item {
    id: root

    required property var tabs
    required property string current
    property Item gridFocusTarget: null

    readonly property Item currentItem: indicator.activeTab
    readonly property bool activeTabFocused: currentItem?.activeFocus ?? false

    signal selected(string tab)

    // M3's minimum indicator length, for a label narrower than the indicator can be.
    readonly property real minimumIndicator: 24
    // The lane at the bottom the indicator and the divider share. The tabs stop above it, so
    // a tab's state layer never draws over the indicator or the rule under it.
    readonly property real indicatorHeight: 3
    // For the offscreen geometry fixture: whether the indicator ends up on the active label
    // is a measurement, not something a source assertion can see.
    readonly property Item indicatorItem: indicator

    function focusCurrentTab(): bool {
        if (!root.currentItem)
            return false;
        root.currentItem.forceActiveFocus();
        return true;
    }

    onCurrentChanged: Qt.callLater(root.focusCurrentTab)
    Component.onCompleted: Qt.callLater(root.focusCurrentTab)

    implicitHeight: Metrics.TABBAR_H

    Row {
        id: row
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.height - root.indicatorHeight

        Repeater {
            id: repeater
            model: root.tabs

            delegate: RippleButton {
                id: tab
                required property int index
                required property var modelData
                readonly property bool active: root.current === modelData.key
                // Published from the delegate because only the delegate knows how wide its
                // own label drew.
                readonly property real labelX: x + (width - label.implicitWidth) / 2
                readonly property real labelWidth: label.implicitWidth

                width: row.width / repeater.count
                height: row.height
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: root.selected(modelData.key)

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    if (!tab.active || root.current !== "wallpaper" || !root.gridFocusTarget)
                        return;
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        event.accepted = true;
                        root.gridFocusTarget.focusEntry();
                    }
                }

                contentItem: Text {
                    id: label
                    text: tab.modelData.label
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Appearance.colors.colOutlineVariant
    }

    Rectangle {
        id: indicator
        anchors.bottom: parent.bottom
        height: root.indicatorHeight
        radius: height / 2
        color: Appearance.colors.colPrimary

        // Both x and width animate: the indicator is as wide as the active label, and no
        // two labels are the same width.
        readonly property Item activeTab: {
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.active)
                    return item;
            }
            return null;
        }

        // Both targets are a function of the active label alone. Deliberately not
        // `x: … - width / 2`: an x binding that reads the animating width re-targets its own
        // animation on every frame the width advances, so the slide chases a destination that
        // keeps moving and never runs its curve to a clean arrival.
        readonly property real targetWidth: activeTab ? Math.max(root.minimumIndicator, activeTab.labelWidth) : 0
        readonly property real targetX: activeTab ? activeTab.labelX + (activeTab.labelWidth - targetWidth) / 2 : 0

        // The card is destroyed and rebuilt every time the dashboard opens, so the first
        // placement is not a move. Without this the indicator slides in from the row's left
        // edge on every open.
        property bool placed: false
        Component.onCompleted: Qt.callLater(() => indicator.placed = true)

        width: targetWidth
        x: targetX

        Behavior on x {
            enabled: indicator.placed
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        // Overshoots its new length and settles back, which is what makes a travelling
        // indicator read as one shape stretching between the labels rather than a block of a
        // new size appearing in a new place.
        Behavior on width {
            enabled: indicator.placed
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial
            }
        }
    }
}
