pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ResourceUsageParse.js" as ResourceUsageParse

/**
 * Current scalar readings preserve their last valid values across transient input failures.
 * Consumers treat history as read-only and observe historyUpdated after coherent mutations.
 */
Singleton {
    id: root

    readonly property alias history: historyModel
    readonly property int historyCapacity: 60

    signal historyUpdated()

    // Memory properties (in KB)
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal

    // Swap properties (in KB)
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0

    // CPU properties
    property real cpuUsage: 0
    property var previousCpuStats: null

    // Formatted strings for display
    property string memoryTotalString: formatBytes(memoryTotal * 1024)
    property string memoryUsedString: formatBytes(memoryUsed * 1024)
    property string swapTotalString: formatBytes(swapTotal * 1024)
    property string swapUsedString: formatBytes(swapUsed * 1024)

    property real previousPollTimestamp: 0

    function formatBytes(bytes: var): string {
        return ResourceUsageParse.formatBytes(bytes);
    }

    function formatRate(bytesPerSecond: var): string {
        return ResourceUsageParse.formatRate(bytesPerSecond);
    }

    function appendHistory(sample: var): void {
        if (historyModel.count >= root.historyCapacity)
            historyModel.remove(0);

        historyModel.append({
            cpuUsage: Number.isFinite(sample.cpuUsage) ? sample.cpuUsage : NaN,
            cpuTemperatureC: Number.isFinite(sample.cpuTemperatureC) ? sample.cpuTemperatureC : NaN,
            memoryUsedPercentage: Number.isFinite(sample.memoryUsedPercentage) ? sample.memoryUsedPercentage : NaN,
            swapUsedPercentage: Number.isFinite(sample.swapUsedPercentage) ? sample.swapUsedPercentage : NaN,
            downloadBytesPerSecond: Number.isFinite(sample.downloadBytesPerSecond) ? sample.downloadBytesPerSecond : NaN,
            uploadBytesPerSecond: Number.isFinite(sample.uploadBytesPerSecond) ? sample.uploadBytesPerSecond : NaN
        });
        root.historyUpdated();
    }

    function clearHistory(): void {
        historyModel.clear();
        root.historyUpdated();
    }

    function poll(appendSample: bool): void {
        const now = Date.now();
        const elapsedMs = root.previousPollTimestamp > 0 ? now - root.previousPollTimestamp : 0;
        const discontinuity = root.previousPollTimestamp > 0 && elapsedMs > 2500;
        root.previousPollTimestamp = now;

        fileMeminfo.reload();
        const memory = ResourceUsageParse.parseMeminfo(fileMeminfo.text());
        let memorySample = NaN;
        let swapSample = NaN;
        if (memory) {
            root.memoryTotal = memory.memoryTotal;
            root.memoryFree = memory.memoryAvailable;
            root.swapTotal = memory.swapTotal;
            root.swapFree = memory.swapFree;
            memorySample = root.memoryUsedPercentage;
            swapSample = root.swapUsedPercentage;
        }

        fileStat.reload();
        const cpuStats = ResourceUsageParse.parseCpuStat(fileStat.text());
        let cpuSample = NaN;
        if (cpuStats) {
            const usage = ResourceUsageParse.calculateCpuUsage(root.previousCpuStats, cpuStats, elapsedMs);
            root.previousCpuStats = cpuStats;
            if (usage !== null) {
                root.cpuUsage = usage;
                cpuSample = usage;
            }
        }

        if (discontinuity) {
            root.clearHistory();
            return;
        }
        if (!appendSample)
            return;

        root.appendHistory({
            cpuUsage: cpuSample,
            cpuTemperatureC: NaN,
            memoryUsedPercentage: memorySample,
            swapUsedPercentage: swapSample,
            downloadBytesPerSecond: NaN,
            uploadBytesPerSecond: NaN
        });
    }

    Component.onCompleted: root.poll(false)

    Timer {
        id: pollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.poll(true)
    }

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
        blockAllReads: true
    }

    FileView {
        id: fileStat
        path: "/proc/stat"
        blockAllReads: true
    }

    ListModel {
        id: historyModel
    }
}
