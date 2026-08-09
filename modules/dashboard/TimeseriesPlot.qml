import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.functions
import qs.services
import "timeseries_plot.js" as Plot

/**
 * A minute of a `ResourceUsage` history role, drawn as a stroked polyline over the pane's
 * fixed sample cadence.
 *
 * The caller names the roles and supplies the scale. A renderer that inferred its own
 * ceiling would rescale under the reader, so a rise in the line could mean either more of
 * the metric or less headroom, and the two would be indistinguishable.
 *
 * The geometry is rebuilt on `historyUpdated` and on nothing else that moves. There is no
 * per-frame scroll: at one sample a second, interpolating the line between ticks would cost
 * a rebuild every frame and show nothing that was not already on the plot.
 */
Item {
    id: root

    // Roles on a `ResourceUsage.history` row. Both series are read from the same rows, so
    // two lines on one plot are always the same instants side by side. An empty secondary
    // role is one series, which is the case that gets the area fill.
    required property string primaryRole
    property string secondaryRole: ""
    property color primaryColor: Appearance.colors.colPrimary
    property color secondaryColor: Appearance.colors.colTertiary
    property string primaryKey: ""
    property string secondaryKey: ""

    // The top of the scale, in the roles' own units. Bounded metrics pass their ceiling and
    // never move it; an unbounded one passes whatever it has settled on.
    property real maximum: 1
    // Drawn only when the caller's ceiling is not implicit — a percentage plot needs no
    // label to say it stops at 100.
    property string ceilingLabel: ""

    property real strokeWidth: 2

    readonly property bool collecting: ResourceUsage.history.count < Plot.MIN_SAMPLES
    // One series gets the area under it; two would hide one another's line where they cross.
    readonly property bool filled: root.secondaryRole === ""

    property var primaryLines: []
    property var primaryAreas: []
    property var secondaryLines: []

    function readSeries(role: string): var {
        const values = [];
        for (let index = 0; index < ResourceUsage.history.count; index++)
            values.push(ResourceUsage.history.get(index)[role]);
        return values;
    }

    function polylines(segments: var): var {
        return segments.map(segment => segment.map(point => Qt.point(point.x, point.y)));
    }

    function rebuild(): void {
        if (root.collecting || body.width <= 0 || body.height <= 0) {
            root.primaryLines = [];
            root.primaryAreas = [];
            root.secondaryLines = [];
            return;
        }

        const segments = Plot.seriesSegments(root.readSeries(root.primaryRole), root.maximum, ResourceUsage.historyCapacity, body.width, body.height);
        root.primaryLines = root.polylines(segments);
        root.primaryAreas = root.filled ? root.polylines(segments.map(segment => Plot.areaPolygon(segment, body.height))) : [];
        root.secondaryLines = root.secondaryRole === "" ? [] : root.polylines(Plot.seriesSegments(root.readSeries(root.secondaryRole), root.maximum, ResourceUsage.historyCapacity, body.width, body.height));
    }

    onMaximumChanged: root.rebuild()
    onPrimaryRoleChanged: root.rebuild()
    onSecondaryRoleChanged: root.rebuild()
    Component.onCompleted: root.rebuild()

    Connections {
        target: ResourceUsage

        // The ring rolls at capacity, so its count stops changing while its contents keep
        // moving. This is the only signal that a sample has arrived.
        function onHistoryUpdated(): void {
            root.rebuild();
        }
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: legend.top
        anchors.bottomMargin: 6
        // A reading at either limit of the scale sits on the box's edge, where half the
        // stroke would fall outside it.
        anchors.topMargin: root.strokeWidth / 2

        onWidthChanged: root.rebuild()
        onHeightChanged: root.rebuild()

        Shape {
            anchors.fill: parent
            visible: !root.collecting
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: ColorUtils.transparentize(root.primaryColor, 0.85)

                PathMultiline {
                    paths: root.primaryAreas
                }
            }

            ShapePath {
                strokeColor: root.primaryColor
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathMultiline {
                    paths: root.primaryLines
                }
            }

            ShapePath {
                strokeColor: root.secondaryColor
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathMultiline {
                    paths: root.secondaryLines
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.collecting
            text: "Collecting 60-second history…"
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        // The scale is only stated where it is not implicit, and then quietly: a ceiling
        // that moves has to be visible, or a rescale reads as a change in the metric.
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            visible: !root.collecting && root.ceilingLabel !== ""
            text: root.ceilingLabel
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
    }

    // The window the plot covers, and which line is which. No axes, ticks or grid: sixty
    // samples across 400px have no room for a scale that would still be legible.
    Item {
        id: legend

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: windowLabel.implicitHeight
        // Kept in the layout while it is hidden: the plot area would otherwise grow by a
        // line the moment the second sample lands, and the card would rearrange under a
        // reader who was watching for exactly that.
        visible: !root.collecting

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // A key carries its series' colour, which is what lets a line be identified
            // without a lookup somewhere else on the card.
            PlotKey {
                text: root.primaryKey
                color: root.primaryColor
            }

            PlotKey {
                text: root.secondaryKey
                color: root.secondaryColor
            }
        }

        Text {
            id: windowLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Last 60 seconds"
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }
}
