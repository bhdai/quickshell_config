import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A screen recording in the bar's status pill. Unlike its neighbours, which are standing
// conditions rendered as a bare glyph, this is a capture running right now and worth
// interrupting for -- so it carries a container of its own and a clock, and gives every
// pixel back the moment the recording stops.
Item {
    id: root

    readonly property color accent: Appearance.colors.colOnErrorContainer

    // Animated separately from the width so the overshoot in expressiveFastSpatial cannot
    // drive a negative width on the way out; the clamp below absorbs it and the pill still
    // springs rather than sliding.
    property real progress: ScreenRecording.active ? 1 : 0

    implicitWidth: pill.implicitWidth * Math.max(0, progress)
    implicitHeight: pill.implicitHeight
    // Excluded from the row -- and from its 8px spacing -- once fully closed.
    visible: progress > 0.001
    opacity: Math.min(1, progress * 1.6)
    clip: true

    Behavior on progress {
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial
        }
    }

    WrapperRectangle {
        id: pill

        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 22
        radius: Appearance.rounding.full
        color: Appearance.colors.colErrorContainer

        leftMargin: 8
        rightMargin: 9

        RowLayout {
            spacing: 5

            MaterialSymbol {
                text: "screen_record"
                fill: 1
                iconSize: 15
                color: root.accent
                Layout.alignment: Qt.AlignVCenter

                // A recording has nothing moving of its own, and a pill that never changes
                // stops being read after the first minute. The clock beside this carries the
                // information; the pulse is only here to hold peripheral vision.
                SequentialAnimation on opacity {
                    running: ScreenRecording.active
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation {
                        to: 0.45
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                // Monospaced so the pill keeps one width as the digits change. In a
                // proportional face every 1 is narrower than every 0, and the whole row to
                // the left of it would shuffle once a second.
                text: ScreenRecording.elapsedText
                visible: ScreenRecording.hasClock
                color: root.accent
                font.family: Appearance.font.family.monospace
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
