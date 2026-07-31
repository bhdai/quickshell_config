import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// M3 primary tabs as #87 resolved them: label-only so the container stays 48, indicator
// hugging the label rather than the cell, 1px divider inside the height.
Item {
    id: root

    property var tabs: ["Calendar", "Wallpaper"]
    property string current: "calendar"

    signal selected(string tab)

    implicitHeight: 48

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
                // Where the indicator has to land. Published from the delegate because only
                // the delegate knows how wide its own label drew.
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

        // Both x and width animate: matchContentSize means the indicator is as wide as the
        // label, and "Calendar" and "Wallpaper" are not the same width.
        x: {
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.active)
                    return item.labelX;
            }
            return 0;
        }
        width: {
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.active)
                    return item.labelWidth;
            }
            return 0;
        }

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
