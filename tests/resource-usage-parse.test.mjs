import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const {
    parseMeminfo,
    parseCpuStat,
    calculateCpuUsage,
    parseNetDev,
    calculateNetworkRates,
    parseDf,
    formatBytes,
    formatRate,
} = loadQmlJs(
    new URL("../services/ResourceUsageParse.js", import.meta.url),
    [
        "parseMeminfo",
        "parseCpuStat",
        "calculateCpuUsage",
        "parseNetDev",
        "calculateNetworkRates",
        "parseDf",
        "formatBytes",
        "formatRate",
    ],
);

test("meminfo reports memory and swap counters in KiB", () => {
    const parsed = parseMeminfo(`MemTotal:       16384000 kB
MemFree:         1000000 kB
MemAvailable:    4096000 kB
SwapTotal:       2097152 kB
SwapFree:         524288 kB
`);

    assert.deepEqual(parsed, {
        memoryTotal: 16384000,
        memoryAvailable: 4096000,
        swapTotal: 2097152,
        swapFree: 524288,
    });
});

test("malformed meminfo is rejected as one reading", () => {
    assert.equal(parseMeminfo("MemTotal: 4096 kB\nMemAvailable: unavailable\n"), null);
    assert.equal(parseMeminfo(`MemTotal:       4096 kB
MemAvailable:   8192 kB
SwapTotal:      1024 kB
SwapFree:       2048 kB
`), null);
});

test("a machine with no configured swap keeps zero totals", () => {
    assert.deepEqual(parseMeminfo(`MemTotal:       8192 kB
MemAvailable:   4096 kB
SwapTotal:         0 kB
SwapFree:          0 kB
`), {
        memoryTotal: 8192,
        memoryAvailable: 4096,
        swapTotal: 0,
        swapFree: 0,
    });
});

test("aggregate CPU totals non-guest fields through steal and combines idle with iowait", () => {
    assert.deepEqual(parseCpuStat("cpu  1 2 3 4 5 6 7 8 900 1000\ncpu0 1 2 3 4 5 6 7 8 9 10\n"), {
        total: 36,
        idle: 9,
    });
});

test("malformed aggregate CPU counters are rejected", () => {
    assert.equal(parseCpuStat("cpu  1 2 3 idle 5 6 7 8\n"), null);
    assert.equal(parseCpuStat("intr 12345\n"), null);
});

test("CPU usage is the busy share of the counter delta", () => {
    assert.equal(calculateCpuUsage(
        { total: 100, idle: 40 },
        { total: 140, idle: 50 },
        1000,
    ), 0.75);
});

test("a measured interval over 2500 ms is a discontinuity", () => {
    const before = { total: 100, idle: 40 };
    const after = { total: 140, idle: 50 };

    assert.equal(calculateCpuUsage(before, after, 2500), 0.75);
    assert.equal(calculateCpuUsage(before, after, 2501), null);
});

test("missing, stationary, or reset CPU counters require a new baseline", () => {
    assert.equal(calculateCpuUsage(null, { total: 140, idle: 50 }, 1000), null);
    assert.equal(calculateCpuUsage({ total: 100, idle: 40 }, { total: 100, idle: 40 }, 1000), null);
    assert.equal(calculateCpuUsage({ total: 100, idle: 40 }, { total: 90, idle: 35 }, 1000), null);
});

test("network counters aggregate every non-loopback interface", () => {
    const parsed = parseNetDev(`Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 5000 50 0 0 0 0 0 0 5000 50 0 0 0 0 0 0
  eth0: 1200 12 0 0 0 0 0 0 3400 34 0 0 0 0 0 0
 wlan0:  800  8 0 0 0 0 0 0  600  6 0 0 0 0 0 0
`);

    assert.deepEqual(parsed, {
        receivedBytes: 2000,
        transmittedBytes: 4000,
    });
});

test("malformed network rows are ignored without contaminating valid counters", () => {
    assert.deepEqual(parseNetDev(`Inter-| Receive | Transmit
broken line
  eth0: 100 1 0 0 0 0 0 0 200 2 0 0 0 0 0 0
 wlan0: 300 packets 0 0 0 0 0 0 400 4 0 0 0 0 0 0
`), {
        receivedBytes: 100,
        transmittedBytes: 200,
    });
    assert.equal(parseNetDev("Inter-| Receive | Transmit\nbroken line\neth0: not counters\n"), null);
});

test("network rates use the measured elapsed time", () => {
    assert.deepEqual(calculateNetworkRates(
        { receivedBytes: 2000, transmittedBytes: 4000 },
        { receivedBytes: 3024, transmittedBytes: 4512 },
        500,
    ), {
        downloadBytesPerSecond: 2048,
        uploadBytesPerSecond: 1024,
    });
});

test("a reset gaps only its network direction and the next reading uses the new baseline", () => {
    const reset = { receivedBytes: 100, transmittedBytes: 5000 };

    assert.deepEqual(calculateNetworkRates(
        { receivedBytes: 400, transmittedBytes: 4000 },
        reset,
        1000,
    ), {
        downloadBytesPerSecond: null,
        uploadBytesPerSecond: 1000,
    });
    assert.deepEqual(calculateNetworkRates(
        reset,
        { receivedBytes: 600, transmittedBytes: 5250 },
        500,
    ), {
        downloadBytesPerSecond: 1000,
        uploadBytesPerSecond: 500,
    });
});

test("df reports root filesystem sizes in bytes", () => {
    const parsed = parseDf(`Filesystem       1B-blocks        Used   Available Use% Mounted on
/dev/nvme0n1p2  107374182400 32212254720 75161927680  30% /
`);

    assert.deepEqual(parsed, {
        totalBytes: 107374182400,
        usedBytes: 32212254720,
        availableBytes: 75161927680,
        usedPercentage: 0.3,
    });
});

test("malformed df output is rejected", () => {
    assert.equal(parseDf("df: /: no such file or directory"), null);
    assert.equal(parseDf("/dev/root 1000 used 500 unknown /"), null);
    assert.equal(parseDf("/dev/root 1000 400 600 unknown /"), null);
});

test("byte formatting uses IEC units at their boundaries", () => {
    assert.equal(formatBytes(0), "0 B");
    assert.equal(formatBytes(1023), "1023 B");
    assert.equal(formatBytes(1024), "1.0 KiB");
    assert.equal(formatBytes(1536), "1.5 KiB");
    assert.equal(formatBytes(1024 ** 2), "1.0 MiB");
    assert.equal(formatBytes(1024 ** 3), "1.0 GiB");
    assert.equal(formatBytes(1024 ** 4), "1.0 TiB");
});

test("rates add per-second notation without changing byte scaling", () => {
    assert.equal(formatRate(1023), "1023 B/s");
    assert.equal(formatRate(1536), "1.5 KiB/s");
});

test("unavailable byte values format as an em dash", () => {
    for (const value of [null, undefined, -1, NaN, Infinity]) {
        assert.equal(formatBytes(value), "—");
        assert.equal(formatRate(value), "—");
    }
});
