import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "network_ceiling.js" as Ceiling

/**
 * What is coming down and what is going up, right now and for the last minute, on the widest
 * card of the destination — the two series here move every second, and the shape of a minute
 * of that is only readable with the horizontal room to draw it.
 *
 * Both directions are stated at the same weight because there is no telling which of the two
 * a reader came for. Neither carries a total since boot: the service does not keep one, and a
 * number that only grows says nothing about what the machine is doing now.
 */
PerformanceCard {
    id: root

    // The scale both lines are drawn against. It is a property of the card rather than of the
    // plot because two series only mean anything against each other on one scale, and because
    // a renderer that chose its own would move it under the reader unannounced.
    property real ceiling: Ceiling.FLOOR_BYTES_PER_SECOND

    // Recomputed from the window that is actually on the plot, so the ceiling describes what
    // is drawn rather than a peak that has since scrolled off it.
    function updateCeiling(): void {
        const download = [];
        const upload = [];
        for (let index = 0; index < ResourceUsage.history.count; index++) {
            const row = ResourceUsage.history.get(index);
            download.push(row.downloadBytesPerSecond);
            upload.push(row.uploadBytesPerSecond);
        }
        root.ceiling = Ceiling.settleCeiling(root.ceiling, Ceiling.ceilingTarget(download, upload));
    }

    // One direction's current reading. Both readings are this component, so the two cannot
    // drift into different sizes and turn equal weight into a claim about which matters.
    component DirectionReading: Row {
        id: reading

        required property string arrow
        required property string rate
        required property color accent

        spacing: 6

        // The colour the direction's line is drawn in, so the headline and the plot are
        // legible as the same two things without reading the keys.
        MaterialSymbol {
            text: reading.arrow
            iconSize: 24
            fill: 1
            color: reading.accent
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
        }

        Text {
            text: reading.rate
            font.family: Appearance.font.family.main
            font.pixelSize: 28
            color: Appearance.colors.colOnLayer2
            anchors.bottom: parent.bottom
        }
    }

    symbol: "network_check"
    title: "Network"

    // The pane is unloaded when another destination is showing, so the card starts again from
    // the floor and takes the window's real ceiling on its first pass — a rise is immediate,
    // so nothing about the plot depends on how long the destination has been open.
    Component.onCompleted: root.updateCeiling()

    Connections {
        target: ResourceUsage

        function onHistoryUpdated(): void {
            root.updateCeiling();
        }
    }

    Row {
        id: headline

        anchors.top: parent.top
        anchors.left: parent.left
        spacing: 28

        // A direction that is rebaselining after an interface change publishes null, which
        // the service's formatter states as an em dash. Its history keeps whatever it had:
        // the row it could not measure is a break in the line, not a reason to drop the rest.
        DirectionReading {
            arrow: "arrow_downward"
            rate: ResourceUsage.formatRate(ResourceUsage.downloadBytesPerSecond)
            accent: Appearance.colors.colPrimary
        }

        DirectionReading {
            arrow: "arrow_upward"
            rate: ResourceUsage.formatRate(ResourceUsage.uploadBytesPerSecond)
            accent: Appearance.colors.colTertiary
        }
    }

    TimeseriesPlot {
        anchors.top: headline.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        primaryRole: "downloadBytesPerSecond"
        primaryKey: "Download"
        primaryColor: Appearance.colors.colPrimary
        secondaryRole: "uploadBytesPerSecond"
        secondaryKey: "Upload"
        secondaryColor: Appearance.colors.colTertiary
        maximum: root.ceiling
        ceilingLabel: ResourceUsage.formatRate(root.ceiling)
    }
}
