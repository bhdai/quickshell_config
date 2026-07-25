import qs.modules.common
import QtQuick

/**
 * The one status element under a detail panel's header: a static divider at rest, an
 * indeterminate scan bar while `scanning`. The panel gives it its width.
 */
Rectangle {
    id: root

    property bool scanning: false

    implicitHeight: 4
    radius: height / 2
    color: root.scanning ? Appearance.colors.colSurfaceContainerHighest : Appearance.colors.colOutlineVariant
    clip: true

    Behavior on color {
        ColorAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveEffects
        }
    }

    Rectangle {
        id: pulse

        width: parent.width * 0.4
        height: parent.height
        radius: height / 2
        color: Appearance.colors.colPrimary
        visible: root.scanning
        // Parked off the leading edge so a stopped scan leaves the divider bare.
        x: -width

        NumberAnimation on x {
            running: root.scanning
            loops: Animation.Infinite
            from: -pulse.width
            to: root.width
            duration: 1200
            easing.type: Easing.InOutQuad
        }
    }
}
