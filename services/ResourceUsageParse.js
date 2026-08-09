.pragma library

function parseMeminfo(text) {
    const values = {};
    for (const line of String(text ?? "").split("\n")) {
        const match = line.match(/^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)\s+kB$/);
        if (match)
            values[match[1]] = Number(match[2]);
    }

    if (["MemTotal", "MemAvailable", "SwapTotal", "SwapFree"].some(key => !Number.isFinite(values[key])))
        return null;
    if (!(values.MemTotal > 0) || values.MemAvailable > values.MemTotal
            || values.SwapTotal < 0 || values.SwapFree > values.SwapTotal)
        return null;

    return {
        memoryTotal: values.MemTotal,
        memoryAvailable: values.MemAvailable,
        swapTotal: values.SwapTotal,
        swapFree: values.SwapFree
    };
}

function parseCpuStat(text) {
    const line = String(text ?? "").split("\n").find(candidate => /^cpu\s/.test(candidate));
    if (!line)
        return null;

    const fields = line.trim().split(/\s+/).slice(1).map(Number);
    if (fields.length < 8 || fields.slice(0, 8).some(value => !Number.isFinite(value) || value < 0))
        return null;

    const counters = fields.slice(0, 8);
    return {
        total: counters.reduce((sum, value) => sum + value, 0),
        idle: counters[3] + counters[4]
    };
}

function calculateCpuUsage(previous, current, elapsedMs) {
    if (!previous || !current || !(elapsedMs > 0 && elapsedMs <= 2500))
        return null;

    const totalDelta = current.total - previous.total;
    const idleDelta = current.idle - previous.idle;
    if (!(totalDelta > 0) || idleDelta < 0 || idleDelta > totalDelta)
        return null;

    return 1 - idleDelta / totalDelta;
}

function parseDf(text) {
    const line = String(text ?? "").split("\n").find(candidate => /\s\/\s*$/.test(candidate));
    if (!line)
        return null;

    const fields = line.trim().split(/\s+/);
    if (fields.length < 6)
        return null;

    const totalBytes = Number(fields[fields.length - 5]);
    const usedBytes = Number(fields[fields.length - 4]);
    const availableBytes = Number(fields[fields.length - 3]);
    const percentage = fields[fields.length - 2];
    if (!(totalBytes > 0) || usedBytes < 0 || availableBytes < 0
            || !Number.isFinite(usedBytes) || !Number.isFinite(availableBytes)
            || !/^\d+%$/.test(percentage))
        return null;

    return {
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        availableBytes: availableBytes,
        usedPercentage: usedBytes / totalBytes
    };
}

function formatBytes(bytes) {
    if (bytes === null || !Number.isFinite(bytes) || bytes < 0)
        return "—";
    if (bytes < 1024)
        return Math.round(bytes) + " B";

    const units = ["KiB", "MiB", "GiB", "TiB"];
    let value = bytes / 1024;
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
    }
    return value.toFixed(1) + " " + units[unit];
}

function formatRate(bytesPerSecond) {
    const formatted = formatBytes(bytesPerSecond);
    return formatted === "—" ? formatted : formatted + "/s";
}
