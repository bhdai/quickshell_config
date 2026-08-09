pragma Singleton
import QtQuick
import Quickshell
import "ResourceUsageParse.js" as ResourceUsageParse

/**
 * Deterministic resource readings for the offscreen Performance fixture. The production
 * service's card-facing data shape is preserved so the production cards cannot distinguish
 * this seam from the live one.
 */
Singleton {
    id: root

    readonly property alias history: historyModel
    readonly property int historyCapacity: 60
    readonly property string profile: Quickshell.env("PERFORMANCE_GEOMETRY_PROFILE") ?? ""
    readonly property bool complete: profile === "complete"

    signal historyUpdated()

    property real memoryTotal: complete ? 16777216 : 8388608
    property real memoryFree: complete ? 4194304 : 3145728
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal

    property real swapTotal: complete ? 4194304 : 0
    property real swapFree: complete ? 1048576 : 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? swapUsed / swapTotal : 0

    property real cpuUsage: complete ? 0.58 : 0.31
    property var cpuTemperature: complete ? 67 : null
    property var cpuTemperatureCritical: complete ? 100 : null

    property var downloadBytesPerSecond: complete ? 1572864 : null
    property var uploadBytesPerSecond: complete ? 262144 : 32768
    property var downloadTotalBytes: complete ? 68719476736 : 2147483648
    property var uploadTotalBytes: complete ? 8589934592 : 1073741824

    property var diskTotalBytes: complete ? 549755813888 : 274877906944
    property var diskUsedBytes: complete ? 412316860416 : 137438953472
    property var diskAvailableBytes: complete ? 128849018880 : 137438953472
    property var diskUsedPercentage: complete ? 0.75 : 0.5

    property string memoryTotalString: formatBytes(memoryTotal * 1024)
    property string memoryUsedString: formatBytes(memoryUsed * 1024)
    property string swapTotalString: formatBytes(swapTotal * 1024)
    property string swapUsedString: formatBytes(swapUsed * 1024)

    function formatBytes(bytes: var): string {
        return ResourceUsageParse.formatBytes(bytes);
    }

    function formatRate(bytesPerSecond: var): string {
        return ResourceUsageParse.formatRate(bytesPerSecond);
    }

    Component.onCompleted: {
        if (root.complete) {
            historyModel.append({
                cpuUsage: 0.42,
                cpuTemperatureC: 62,
                memoryUsedPercentage: 0.68,
                swapUsedPercentage: 0.60,
                downloadBytesPerSecond: 1048576,
                uploadBytesPerSecond: 131072
            });
        }
        historyModel.append({
            cpuUsage: root.cpuUsage,
            cpuTemperatureC: root.complete ? root.cpuTemperature : NaN,
            memoryUsedPercentage: root.memoryUsedPercentage,
            swapUsedPercentage: root.complete ? root.swapUsedPercentage : NaN,
            downloadBytesPerSecond: root.complete ? root.downloadBytesPerSecond : NaN,
            uploadBytesPerSecond: root.uploadBytesPerSecond
        });
        root.historyUpdated();
    }

    ListModel {
        id: historyModel
    }
}
