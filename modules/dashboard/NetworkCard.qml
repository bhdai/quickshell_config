import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "network_ceiling.js" as Ceiling

/**
 * Two flows in opposite directions, on the widest card of the destination because these are
 * the series that move every second and the shape of a minute of that needs the room.
 *
 * Each direction is a body rather than a line of text: a filled circle in its own colour
 * carrying its arrow, the rate beside it. That colour is the third statement of the same
 * thing — chip, plot line, key — so a reader matches a line to a direction without a lookup.
 *
 * The card states three different windows, and each one is named exactly once, where that
 * window already lives: now, at the top; the peak of the plotted minute, on the keys under
 * the plot the minute belongs to; and the counters since boot, off in the corner. Repeating
 * "peak" and "since boot" against every reading is what made an earlier draft of this card
 * read as a table of qualifiers rather than as four numbers.
 *
 * Spec #150 ruled the counters out as answering a different question from "what is happening
 * now". They are here because they were asked for, and they are the quietest thing on the
 * card because that judgement about them still holds.
 */
PerformanceCard {
    id: root

    // Two current readings rather than the CPU card's one, and a plot that is the point of
    // the destination. The rate is stated well below a single-figure headline's size, and
    // takes its weight from the chip beside it instead.
    readonly property int rateSize: 20
    readonly property int chipSize: 30

    // The scale both lines are drawn against. It is a property of the card rather than of the
    // plot because two series only mean anything against each other on one scale, and because
    // a renderer that chose its own would move it under the reader unannounced.
    property real ceiling: Ceiling.FLOOR_BYTES_PER_SECOND
    // The fastest reading each direction has in the window the plot covers, or null where it
    // has none at all.
    property var downloadPeak: null
    property var uploadPeak: null

    // One pass over the window the plot draws, so the peaks stated on the keys and the scale
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

    // The card's signature: a direction given a body, in its series' own container colour, at
    // the full radius against the card's small one. On-container is what the role guarantees
    // legible against its fill on any generated palette — the exact line colour would be a
    // contrast gamble every time the wallpaper changes.
    component DirectionReading: Row {
        id: reading

        required property string arrow
        required property string rate
        required property color container
        required property color onContainer

        spacing: 10

        Rectangle {
            implicitWidth: root.chipSize
            implicitHeight: root.chipSize
            radius: Appearance.rounding.full
            color: reading.container
            anchors.verticalCenter: parent.verticalCenter

            MaterialSymbol {
                anchors.centerIn: parent
                text: reading.arrow
                iconSize: 18
                fill: 1
                color: reading.onContainer
            }
        }

        Text {
            // Held at the widest rate the formatter can produce rather than at this second's
            // string, so the upload chip does not shuffle sideways every time the download
            // rate changes width.
            width: Math.max(implicitWidth, rateColumn.width)
            text: reading.rate
            font.family: Appearance.font.family.main
            font.pixelSize: root.rateSize
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component CounterArrow: MaterialSymbol {
        iconSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
        anchors.verticalCenter: parent.verticalCenter
    }

    component Counter: Text {
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnLayer2
        anchors.verticalCenter: parent.verticalCenter
    }

    symbol: "network_check"
    title: "Network"

    // Four digits, a decimal and the longest unit is as wide as a formatted rate gets, so
    // this is the column both directions are laid out in.
    TextMetrics {
        id: rateColumn

        font.family: Appearance.font.family.main
        font.pixelSize: root.rateSize
        font.weight: Font.DemiBold
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

    Item {
        id: headline

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: Math.max(rates.implicitHeight, counters.implicitHeight)

        Row {
            id: rates

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24

            // A direction that is rebaselining after an interface change publishes null,
            // which the service's formatter states as an em dash. Its history keeps whatever
            // it had: the row it could not measure is a break in the line, not a reason to
            // drop the rest.
            DirectionReading {
                arrow: "arrow_downward"
                rate: ResourceUsage.formatRate(ResourceUsage.downloadBytesPerSecond)
                container: Appearance.colors.colPrimaryContainer
                onContainer: Appearance.colors.colOnPrimaryContainer
            }

            DirectionReading {
                arrow: "arrow_upward"
                rate: ResourceUsage.formatRate(ResourceUsage.uploadBytesPerSecond)
                container: Appearance.colors.colTertiaryContainer
                onContainer: Appearance.colors.colOnTertiaryContainer
            }
        }

        // The one reading here that is not about the last minute, so it is named for its own
        // window and kept out of the way of the ones that are.
        Column {
            id: counters

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Since boot"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                anchors.right: parent.right
            }

            // The same arrows the chips carry, from the same font, rather than the text
            // arrows a body font may not have a glyph for.
            Row {
                anchors.right: parent.right
                spacing: 4

                CounterArrow {
                    text: "arrow_downward"
                }

                Counter {
                    text: ResourceUsage.formatBytes(ResourceUsage.downloadTotalBytes)
                    rightPadding: 10
                }

                CounterArrow {
                    text: "arrow_upward"
                }

                Counter {
                    text: ResourceUsage.formatBytes(ResourceUsage.uploadTotalBytes)
                }
            }
        }
    }

    TimeseriesPlot {
        anchors.top: headline.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        primaryRole: "downloadBytesPerSecond"
        primaryKey: "Download"
        primaryColor: Appearance.colors.colPrimary
        secondaryRole: "uploadBytesPerSecond"
        secondaryKey: "Upload"
        secondaryColor: Appearance.colors.colTertiary
        // The keys carry each direction's fastest second, and the caption says once what both
        // of those numbers are and which minute they are from.
        primaryValue: ResourceUsage.formatRate(root.downloadPeak)
        secondaryValue: ResourceUsage.formatRate(root.uploadPeak)
        windowLabel: "Peaks · last 60 seconds"
        maximum: root.ceiling
        ceilingLabel: ResourceUsage.formatRate(root.ceiling)
    }
}
