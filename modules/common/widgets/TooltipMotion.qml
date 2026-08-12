import QtQuick
import qs.modules.common

/**
 * The tooltip's entrance: scale 0.8 → 1 with a fade, played once when `target` is created.
 *
 * There is no exit half. Tooltips here hide the instant the pointer leaves, so the surface is
 * already gone by the time an exit animation would run.
 *
 * `animate: false` skips straight to the resting state. TooltipManager sets it that way when
 * another tooltip was on screen a moment ago, so dragging along a row of bar icons reads as
 * one chip travelling rather than one entrance per icon, none of them finishing.
 */
Item {
    id: root

    required property Item target
    property bool animate: true

    visible: false

    Component.onCompleted: {
        if (!root.animate)
            return;
        root.target.opacity = 0;
        root.target.scale = 0.8;
        enter.start();
    }

    ParallelAnimation {
        id: enter

        NumberAnimation {
            target: root.target
            property: "scale"
            from: 0.8
            to: 1
            duration: 350
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial
        }

        NumberAnimation {
            target: root.target
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveEffects
        }
    }
}
