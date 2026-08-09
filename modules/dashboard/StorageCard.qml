import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.services
import "storage_gauge.js" as Gauge

/**
 * How full the root filesystem is, as a gauge, a percentage and the capacity behind it.
 *
 * The one card on this destination with no history under it. A filesystem fills over hours,
 * and sixty seconds of that would be a flat line drawn to imply it was worth watching. What
 * it gets instead is the destination's only closed shape: everything else here is a line
 * running off the left edge, and this is a quantity with an end.
 *
 * The gauge is Material 3's progress anatomy at gauge size, the same one `StyledProgressBar`
 * draws flat — a rounded active arc, a track broken away from it by the same 4px, and a dot
 * marking where a full filesystem would end. Occupancy and the percentage are the same
 * reading twice, which is why they share a colour and, in warning state, will share that too.
 */
PerformanceCard {
    id: root

    readonly property int gaugeSize: 128
    readonly property int gaugeStroke: 8
    // The stroke straddles the path, so the arc is drawn half a stroke inside the edge.
    readonly property real gaugeRadius: (root.gaugeSize - root.gaugeStroke) / 2

    // Nothing is known about the filesystem until the first `df` returns, and 0% is a
    // filesystem that exists and is empty.
    readonly property bool occupancyKnown: ResourceUsage.diskUsedPercentage !== null

    // The pane is destroyed while another destination is showing, so this runs on every
    // arrival rather than once a session: the gauge sweeps up to the reading and the figure
    // counts with it. It is the one piece of motion on a card whose number holds still for
    // an hour at a time.
    property real revealed: 0
    readonly property real shownOccupancy: root.occupancyKnown ? ResourceUsage.diskUsedPercentage * root.revealed : 0
    readonly property var arcs: Gauge.occupancyArcs(root.shownOccupancy, root.gaugeRadius, root.gaugeStroke)

    symbol: "hard_drive"
    title: "Storage"

    Component.onCompleted: root.revealed = 1

    Behavior on revealed {
        NumberAnimation {
            duration: 550
            easing.type: Easing.BezierSpline
            // Deliberately not the overshooting spatial curve: an arc that ran past its
            // reading and came back would report a fuller disk than the machine has.
            easing.bezierCurve: Appearance.animation.expressiveEffects
        }
    }

    Item {
        id: gauge

        width: root.gaugeSize
        height: root.gaugeSize
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // What is left of the filesystem, drawn first so the reading is never underneath
            // the room it has to grow into.
            ShapePath {
                strokeColor: Appearance.colors.colSecondaryContainer
                strokeWidth: root.gaugeStroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: gauge.width / 2
                    centerY: gauge.height / 2
                    radiusX: root.gaugeRadius
                    radiusY: root.gaugeRadius
                    startAngle: root.arcs.trackStartAngle
                    sweepAngle: root.arcs.trackSweep
                }
            }

            ShapePath {
                strokeColor: Appearance.colors.colSecondary
                strokeWidth: root.gaugeStroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: gauge.width / 2
                    centerY: gauge.height / 2
                    radiusX: root.gaugeRadius
                    radiusY: root.gaugeRadius
                    startAngle: Gauge.START_ANGLE
                    sweepAngle: root.arcs.activeSweep
                }
            }
        }

        // Where a full filesystem would end. In the arc's own colour because that is what
        // would eventually reach it, and gone once it has.
        Rectangle {
            readonly property real endAngle: (Gauge.START_ANGLE + Gauge.SWEEP) * Math.PI / 180

            width: root.gaugeStroke
            height: root.gaugeStroke
            radius: Appearance.rounding.full
            color: Appearance.colors.colSecondary
            visible: root.arcs.stopVisible
            x: gauge.width / 2 + root.gaugeRadius * Math.cos(endAngle) - width / 2
            y: gauge.height / 2 + root.gaugeRadius * Math.sin(endAngle) - height / 2
        }

        Column {
            anchors.centerIn: parent

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Text {
                    text: root.occupancyKnown ? Math.round(root.shownOccupancy * 100) : "—"
                    font.family: Appearance.font.family.main
                    font.pixelSize: 36
                    color: Appearance.colors.colOnLayer2
                    anchors.bottom: parent.bottom
                }

                Text {
                    text: "%"
                    visible: root.occupancyKnown
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                    anchors.bottom: parent.bottom
                    // Lifted onto the figure's digits rather than hanging under them, as on
                    // the weather tiles.
                    anchors.bottomMargin: 6
                }
            }

            // A gauge could as easily be read as the space left, and one word settles it.
            Text {
                text: "used"
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }

    Column {
        anchors.left: gauge.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Which filesystem all of this is about, before any of it is stated — the card
        // reports on one mount and never offers a choice of another.
        Text {
            text: "Root filesystem"
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        Text {
            text: ResourceUsage.formatBytes(ResourceUsage.diskUsedBytes)
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
        }

        Text {
            text: `of ${ResourceUsage.formatBytes(ResourceUsage.diskTotalBytes)}`
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        // Not the total less the used: a filesystem keeps blocks back that nothing here can
        // spend, so this is the only line on the card that says how much more will fit.
        Text {
            text: `${ResourceUsage.formatBytes(ResourceUsage.diskAvailableBytes)} free`
            topPadding: 10
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer2
        }
    }
}
