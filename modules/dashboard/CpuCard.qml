import QtQuick
import qs.modules.common
import qs.services

/**
 * Aggregate CPU usage now, with the last minute of it under the number, and the package
 * temperature beside it.
 *
 * Temperature is a second reading rather than a second line: degrees and percent share no
 * scale, and putting them on one would make the plot's vertical axis mean two things at
 * once. It carries the machine's own critical threshold because 78°C means nothing until it
 * is read against the limit of the part it was measured on.
 */
PerformanceCard {
    id: root

    // 0°C is a reading a machine can genuinely take, so an absent sensor has to be absent
    // rather than cold.
    readonly property bool temperatureAvailable: ResourceUsage.cpuTemperature !== null
    readonly property string temperatureText: root.temperatureAvailable ? `${ResourceUsage.cpuTemperature}°C` : "—"
    // A threshold this machine did not report is not one the card may state, and a threshold
    // standing on its own beside an em dash describes nothing.
    readonly property string criticalText: root.temperatureAvailable && ResourceUsage.cpuTemperatureCritical !== null ? `Critical ${ResourceUsage.cpuTemperatureCritical}°C` : ""

    symbol: "developer_board"
    title: "CPU"

    Row {
        id: headline

        anchors.top: parent.top
        anchors.left: parent.left
        spacing: 2

        Text {
            text: Math.round(ResourceUsage.cpuUsage * 100)
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
    }

    Column {
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 2

        Text {
            text: root.temperatureText
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
            anchors.right: parent.right
        }

        Text {
            text: root.criticalText
            visible: root.criticalText !== ""
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            anchors.right: parent.right
        }
    }

    TimeseriesPlot {
        anchors.top: headline.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        primaryRole: "cpuUsage"
        primaryKey: "Usage"
        primaryColor: Appearance.colors.colPrimary
        // A fraction of the cores available, so the ceiling is the machine being fully
        // busy. Fixed, and left unlabelled: a usage plot that rescaled would draw a quiet
        // minute and a saturated one as the same shape.
        maximum: 1
    }
}
