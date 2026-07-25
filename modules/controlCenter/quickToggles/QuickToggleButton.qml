import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    property string buttonIcon

    // The one toggled-foreground token for every quick toggle; subclasses that bring their
    // own contentItem tint it with this rather than reaching for a raw m3colors entry.
    readonly property color colForeground: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0

    baseWidth: 50
    baseHeight: 50
    clickedWidth: baseWidth + 8
    toggled: false
    // ON is signalled by shape and fill alone — a reduced radius over the accent fill — while
    // a press is transient: wider and rounder for as long as it is held, then back to base.
    // The pressed radius is derived rather than taken from rounding.full, whose 9999 would
    // animate through a long stretch of values the shape has already clamped away.
    buttonRadius: toggled ? Appearance.rounding.small : Appearance.rounding.large
    buttonRadiusPressed: baseHeight / 2
    bounce: true

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: button.colForeground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }
    }
}
