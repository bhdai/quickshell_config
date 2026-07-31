import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "dashboard_metrics.js" as Metrics

/**
 * Material 3 primary tabs: equal-width, label-only, with the indicator hugging the
 * rendered label rather than the cell. `tabs` are labels; the signal carries the
 * lowercased name the dashboard and its IPC use.
 */
Item {
    id: root

    property var tabs: ["Calendar", "Wallpaper"]
    property string current: "calendar"

    signal selected(string tab)

    // M3's minimum indicator length, for a label narrower than the indicator can be.
    readonly property real minimumIndicator: 24
    // For the offscreen geometry fixture: whether the indicator ends up on the active label
    // is a measurement, not something a source assertion can see.
    readonly property Item indicatorItem: indicator

    implicitHeight: Metrics.TABBAR_H

    Row {
        id: row
        anchors.fill: parent

        Repeater {
            id: repeater
            model: root.tabs

            delegate: RippleButton {
                id: tab
                required property int index
                required property var modelData
                readonly property bool active: root.current === modelData.toLowerCase()
                // Published from the delegate because only the delegate knows how wide its
                // own label drew.
                readonly property real labelX: x + (width - label.implicitWidth) / 2
                readonly property real labelWidth: label.implicitWidth

                width: row.width / repeater.count
                height: root.height
                buttonRadius: 0
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: root.selected(modelData.toLowerCase())

                contentItem: Text {
                    id: label
                    text: tab.modelData
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
        height: 3
        radius: 1.5
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

        width: activeTab ? Math.max(root.minimumIndicator, activeTab.labelWidth) : 0
        x: activeTab ? activeTab.labelX + (activeTab.labelWidth - width) / 2 : 0

        Behavior on x {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
    }
}
