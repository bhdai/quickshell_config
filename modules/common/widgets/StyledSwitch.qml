import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Material 3 switch for the detail panels' "Use Bluetooth" / "Use Wi-Fi" rows.
 *
 * Two-way: `checked` is whatever the caller bound it to, and a press reports `toggled()` for
 * the caller to write back to that source. The control never assigns `checked` itself —
 * QtQuick.Controls does that on release while `checkable`, which would drop the caller's
 * binding and leave the switch lying about an adapter that changed from elsewhere.
 */
Switch {
    id: root

    checkable: false

    implicitWidth: 52
    implicitHeight: 32
    padding: 0

    onClicked: root.toggled()

    indicator: Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Appearance.colors.colOutline

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }

        Rectangle {
            id: handle
            // M3 grows the handle as it travels to the checked end of the track.
            width: root.checked ? 24 : 16
            height: width
            radius: width / 2
            color: root.checked ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 4

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveEffects
                }
            }
        }
    }

    contentItem: Item {}

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
