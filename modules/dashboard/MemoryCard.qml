import QtQuick
import qs.modules.common
import qs.services

/**
 * RAM now with the capacity behind it, and swap as a second reading on the same card and a
 * second line on the same plot.
 *
 * Swap is here rather than on a card of its own because a machine reaching past RAM is one
 * movement: split across two cards it would read as two unrelated numbers, and the reader
 * would have to line up their timelines to see that one caused the other.
 */
PerformanceCard {
    id: root

    // Swap that was never configured is not swap sitting empty. A zero reading would report
    // on a resource this machine does not have, so the reading and the series both go — and
    // nothing about the card's size follows from which machine this is.
    readonly property bool swapConfigured: ResourceUsage.swapTotal > 0

    symbol: "memory"
    title: "Memory"

    Row {
        id: headline

        anchors.top: parent.top
        anchors.left: parent.left
        spacing: 2

        Text {
            text: Math.round(ResourceUsage.memoryUsedPercentage * 100)
            font.family: Appearance.font.family.main
            font.pixelSize: 36
            color: Appearance.colors.colOnLayer2
            anchors.bottom: parent.bottom
        }

        Text {
            text: "%"
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            anchors.bottom: parent.bottom
            // Lifted onto the figure's digits rather than hanging under them, as on the
            // weather tiles.
            anchors.bottomMargin: 6
        }

        Text {
            text: `${ResourceUsage.memoryUsedString} / ${ResourceUsage.memoryTotalString}`
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            leftPadding: 8
        }
    }

    Column {
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 2
        visible: root.swapConfigured

        // Named before it is stated: a used-of-total in the corner of a memory card would
        // otherwise be read as another way of saying the headline.
        Text {
            text: "Swap"
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            anchors.right: parent.right
        }

        Text {
            text: `${ResourceUsage.swapUsedString} / ${ResourceUsage.swapTotalString}`
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
            anchors.right: parent.right
        }
    }

    TimeseriesPlot {
        anchors.top: headline.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        primaryRole: "memoryUsedPercentage"
        primaryKey: "RAM"
        primaryColor: Appearance.colors.colPrimary
        secondaryRole: root.swapConfigured ? "swapUsedPercentage" : ""
        secondaryKey: root.swapConfigured ? "Swap" : ""
        secondaryColor: Appearance.colors.colTertiary
        // Both series are fractions of their own resource, so one 0–100% scale is what makes
        // them comparable at all. Fixed and unlabelled: a ceiling that moved would draw a
        // machine at half its RAM and one at all of it as the same shape.
        maximum: 1
    }
}
