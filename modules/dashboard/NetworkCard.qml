import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "network_ceiling.js" as Ceiling

/**
 * What is coming down and what is going up: the rate now, the fastest second of the minute on
 * the plot, and what the interfaces have carried since boot — one line each, on the widest
 * card of the destination, because these two series move every second and the shape of a
 * minute of that is only readable with the horizontal room to draw it.
 *
 * The two directions are given identical treatment because there is no telling which of them
 * a reader came for. Spec #150 ruled the totals out as answering a different question from
 * "what is happening now"; they are here because they were asked for, and they say which
 * window they belong to so that they cannot be mistaken for the one the plot covers.
 */
PerformanceCard {
    id: root

    // Four readings on this card where the CPU card has one, so the current rates are stated
    // well below a single-figure headline's size: at 36px they would leave the peak and the
    // counter nowhere to go, and take the height out of the plot.
    readonly property int rateSize: 20

    // The scale both lines are drawn against. It is a property of the card rather than of the
    // plot because two series only mean anything against each other on one scale, and because
    // a renderer that chose its own would move it under the reader unannounced.
    property real ceiling: Ceiling.FLOOR_BYTES_PER_SECOND
    // The fastest reading each direction has in the window the plot covers, or null where it
    // has none at all.
    property var downloadPeak: null
    property var uploadPeak: null

    // One pass over the window the plot draws, so the peaks stated on the card and the scale
    // the lines are drawn against cannot disagree, and neither can outlast a peak that has
    // scrolled off the plot.
    function updateWindow(): void {
        const download = [];
        const upload = [];
        for (let index = 0; index < ResourceUsage.history.count; index++) {
            const row = ResourceUsage.history.get(index);
            download.push(row.downloadBytesPerSecond);
            upload.push(row.uploadBytesPerSecond);
        }

        root.downloadPeak = Ceiling.peakRate(download);
        root.uploadPeak = Ceiling.peakRate(upload);
        root.ceiling = Ceiling.settleCeiling(root.ceiling, Ceiling.ceilingTarget(root.downloadPeak, root.uploadPeak));
    }

    // The counter is dated where it stands. The peak beside it belongs to the minute on the
    // plot, which the plot labels for itself; an unqualified total next to it would read as
    // another number about that same minute.
    function pastText(peakBytesPerSecond: var, totalBytes: var): string {
        return `peak ${ResourceUsage.formatRate(peakBytesPerSecond)} · ${ResourceUsage.formatBytes(totalBytes)} since boot`;
    }

    // A direction, in the colour its line is drawn in, so the headline and the plot are
    // legible as the same two things without going by way of the keys.
    component DirectionArrow: MaterialSymbol {
        iconSize: root.rateSize
        fill: 1
    }

    component CurrentRate: Text {
        // Held at the widest rate the formatter can produce rather than at this second's
        // string, so the readings beside it do not slide left and right as traffic changes
        // the width of the number in front of them.
        width: Math.max(implicitWidth, rateColumn.width)
        font.family: Appearance.font.family.main
        font.pixelSize: root.rateSize
        color: Appearance.colors.colOnLayer2
    }

    component PastReadings: Text {
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        leftPadding: 8
    }

    symbol: "network_check"
    title: "Network"

    // Four digits, a decimal and the longest unit is as wide as a formatted rate gets, so
    // this is the column both directions are laid out in.
    TextMetrics {
        id: rateColumn

        font.family: Appearance.font.family.main
        font.pixelSize: root.rateSize
        text: "1023.9 KiB/s"
    }

    // The pane is unloaded when another destination is showing, so the card starts again from
    // the floor and takes the window's real ceiling on its first pass — a rise is immediate,
    // so nothing about the plot depends on how long the destination has been open.
    Component.onCompleted: root.updateWindow()

    Connections {
        target: ResourceUsage

        function onHistoryUpdated(): void {
            root.updateWindow();
        }
    }

    // A column per kind of reading rather than a row per direction: the grid takes each
    // column's width from the widest cell in it, so download and upload line up under one
    // another without a width being written down anywhere.
    Grid {
        id: headline

        anchors.top: parent.top
        anchors.left: parent.left
        columns: 3
        columnSpacing: 8
        rowSpacing: 2
        verticalItemAlignment: Grid.AlignVCenter

        // A direction that is rebaselining after an interface change publishes null, which
        // the service's formatter states as an em dash. Its history keeps whatever it had:
        // the row it could not measure is a break in the line, not a reason to drop the rest.
        DirectionArrow {
            text: "arrow_downward"
            color: Appearance.colors.colPrimary
        }

        CurrentRate {
            text: ResourceUsage.formatRate(ResourceUsage.downloadBytesPerSecond)
        }

        PastReadings {
            text: root.pastText(root.downloadPeak, ResourceUsage.downloadTotalBytes)
        }

        DirectionArrow {
            text: "arrow_upward"
            color: Appearance.colors.colTertiary
        }

        CurrentRate {
            text: ResourceUsage.formatRate(ResourceUsage.uploadBytesPerSecond)
        }

        PastReadings {
            text: root.pastText(root.uploadPeak, ResourceUsage.uploadTotalBytes)
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
