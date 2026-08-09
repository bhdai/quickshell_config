import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "dashboard_metrics.js" as Metrics

/**
 * Material 3 primary tabs: equal-width cells holding an icon over a label, with the indicator
 * hugging those two lines rather than the cell. Each tab carries a stable key separately from
 * its presentation label and icon, and the signal carries that key.
 */
Item {
    id: root

    required property var tabs
    required property string current
    // The width this bar will have once the card has finished resizing to the destination
    // being selected. Handed down rather than measured here: while a switch runs, everything
    // this bar is laid out in is still travelling, and an indicator aimed at a width that
    // moves every frame never gets to run its curve.
    required property real settledBarWidth
    property Item gridFocusTarget: null

    readonly property int currentIndex: root.tabs.findIndex(tab => tab.key === root.current)

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

            delegate: Item {
                id: tab
                required property int index
                required property var modelData
                readonly property bool active: root.current === modelData.key
                // Published from the delegate because only the delegate knows how wide its
                // own two lines drew. Deliberately the natural width of the content and not
                // where the content ended up: this never depends on the cell the delegate was
                // laid into, which makes it the one geometry the indicator may read mid-move.
                readonly property real contentWidth: Math.max(icon.implicitWidth, label.implicitWidth)

                width: row.width / repeater.count
                height: row.height

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    if (!tab.active || root.current !== "wallpaper" || !root.gridFocusTarget)
                        return;
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        event.accepted = true;
                        root.gridFocusTarget.focusEntry();
                    }
                }

                // The whole cell is what accepts the pointer, so the whole cell is what
                // lights up. A layer hugging the two lines was tried and reads wrong: it
                // lit from anywhere in the tab, which puts the response on a shape the
                // pointer is not necessarily over.
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: hover.hovered ? Appearance.colors.colLayer1Hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animation.expressiveEffects
                        }
                    }
                }

                Column {
                    id: content
                    anchors.centerIn: parent

                    MaterialSymbol {
                        id: icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.icon
                        iconSize: 24
                        fill: tab.active ? 1 : 0
                        color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant

                        // The glyph filling in is what says the destination became current,
                        // so it runs on the same clock as the colour it fills into.
                        Behavior on fill {
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animation.expressiveEffects
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                            }
                        }
                    }

                    Text {
                        id: label
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.label
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                            }
                        }
                    }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.selected(tab.modelData.key)
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

        // Found by asking the delegates rather than by indexing them, so it is null until they
        // exist. It is the bar's focus target as well as the content the indicator is as wide
        // as; where that content sits is not read from it.
        readonly property Item activeTab: {
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.active)
                    return item;
            }
            return null;
        }

        // One tab's share of the bar once the card has settled — the same stride idiom the
        // workspace indicator's row is built from, and for the same reason: a position that is
        // arithmetic from an index and a width that does not move can be aimed at on the frame
        // of the click. A Behavior's animation restarts from wherever it currently is every
        // time its target changes, so an indicator placed over the laid-out row instead is
        // re-pinned on every frame the card resizes and only sets off once the card has
        // already arrived.
        readonly property real stride: root.settledBarWidth / repeater.count

        // The width is the active tab's content and the position is arithmetic, so the two
        // travel on their own clocks. Deliberately not `x: … - width / 2`: an x binding that
        // reads the animating width re-targets its own animation on every frame the width
        // advances, which is the same freeze one level down.
        readonly property real targetWidth: activeTab ? Math.max(root.minimumIndicator, activeTab.contentWidth) : 0
        readonly property real targetX: stride * root.currentIndex + (stride - targetWidth) / 2

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
