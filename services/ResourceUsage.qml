pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ResourceUsageParse.js" as ResourceUsageParse
import "cpu_temperature.js" as CpuTemperature

/**
 * CPU, memory, and swap scalars preserve their last valid values across transient input
 * failures; temperature becomes null when its resolved sensor disappears. Consumers treat
 * history as read-only and observe historyUpdated after coherent mutations.
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
    property var cpuTemperature: null
    property var cpuTemperatureCritical: null
    property string cpuTemperatureChip: ""
    property string cpuTemperatureLabel: ""

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

    function acceptCpuTemperatureSensor(stdout: string): void {
        const sensor = CpuTemperature.parseSensorLine(stdout);
        if (!sensor) {
            root.cpuTemperature = null;
            root.cpuTemperatureCritical = null;
            root.cpuTemperatureChip = "";
            root.cpuTemperatureLabel = "";
            fileCpuTemperature.path = "";
            return;
        }

        root.cpuTemperatureChip = sensor.chip;
        root.cpuTemperatureLabel = sensor.label;
        root.cpuTemperatureCritical = sensor.criticalCelsius;
        fileCpuTemperature.path = sensor.path;
    }

    function rediscoverCpuTemperature(): void {
        root.cpuTemperature = null;
        root.cpuTemperatureCritical = null;
        root.cpuTemperatureChip = "";
        root.cpuTemperatureLabel = "";
        fileCpuTemperature.path = "";
        cpuTemperatureResolver.running = true;
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

        let temperatureSample = NaN;
        if (fileCpuTemperature.path) {
            fileCpuTemperature.reload();
            const temperature = CpuTemperature.parseTemperature(fileCpuTemperature.text());
            root.cpuTemperature = temperature;
            if (temperature !== null)
                temperatureSample = temperature;
        }

        if (discontinuity) {
            root.clearHistory();
            return;
        }
        if (!appendSample)
            return;

        root.appendHistory({
            cpuUsage: cpuSample,
            cpuTemperatureC: temperatureSample,
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

    Process {
        id: cpuTemperatureResolver

        running: true
        command: ["sh", "-c", [
            "for want in coretemp k10temp acpitz; do",
            "  for d in /sys/class/hwmon/hwmon*; do",
            "    [ -r \"$d/name\" ] || continue",
            "    read -r n < \"$d/name\"",
            "    [ \"$n\" = \"$want\" ] || continue",
            "    pick=",
            "    for l in \"$d\"/temp*_label; do",
            "      [ -r \"$l\" ] || continue",
            "      read -r lbl < \"$l\"",
            "      c=${l%_label}",
            "      read -r v < \"${c}_input\" 2>/dev/null || continue",
            "      [ \"$v\" -gt 0 ] 2>/dev/null || continue",
            "      case \"$lbl\" in",
            "        \"Package id \"*|Tdie) pick=$c; break ;;",
            "        Tctl) [ -n \"$pick\" ] || pick=$c ;;",
            "      esac",
            "    done",
            "    if [ -z \"$pick\" ]; then",
            "      for i in \"$d\"/temp*_input; do",
            "        read -r v < \"$i\" 2>/dev/null || continue",
            "        [ \"$v\" -gt 0 ] 2>/dev/null || continue",
            "        pick=${i%_input}; break",
            "      done",
            "    fi",
            "    [ -n \"$pick\" ] || continue",
            "    lbl=; [ -r \"${pick}_label\" ] && read -r lbl < \"${pick}_label\"",
            "    crit=; [ -r \"${pick}_crit\" ] && read -r crit < \"${pick}_crit\"",
            "    printf '%s\\t%s\\t%s\\t%s\\n' \"$n\" \"$lbl\" \"${pick}_input\" \"$crit\"",
            "    exit 0",
            "  done",
            "done",
            "exit 1"
        ].join("\n")]
        stdout: StdioCollector {
            id: cpuTemperatureResolverOutput
        }
        onExited: root.acceptCpuTemperatureSensor(cpuTemperatureResolverOutput.text)
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

    FileView {
        id: fileCpuTemperature

        blockAllReads: true
        printErrors: false
        onLoaded: root.cpuTemperature = CpuTemperature.parseTemperature(fileCpuTemperature.text())
        onLoadFailed: root.rediscoverCpuTemperature()
    }

    ListModel {
        id: historyModel
    }
}
