import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { parseSensorLine, parseTemperature } = loadQmlJs(
    new URL("../services/cpu_temperature.js", import.meta.url),
    ["parseSensorLine", "parseTemperature"],
);

test("coretemp resolver output publishes the package channel and critical temperature", () => {
    assert.deepEqual(parseSensorLine(
        "coretemp\tPackage id 0\t/sys/class/hwmon/hwmon7/temp1_input\t100000\n",
    ), {
        chip: "coretemp",
        label: "Package id 0",
        path: "/sys/class/hwmon/hwmon7/temp1_input",
        criticalCelsius: 100,
    });
});

test("resolver output keeps sensors whose critical temperature or label is absent", () => {
    assert.deepEqual(parseSensorLine(
        "k10temp\tTdie\t/sys/class/hwmon/hwmon3/temp2_input\t\n",
    ), {
        chip: "k10temp",
        label: "Tdie",
        path: "/sys/class/hwmon/hwmon3/temp2_input",
        criticalCelsius: null,
    });
    assert.deepEqual(parseSensorLine(
        "acpitz\t\t/sys/class/hwmon/hwmon2/temp1_input\t\n",
    ), {
        chip: "acpitz",
        label: "",
        path: "/sys/class/hwmon/hwmon2/temp1_input",
        criticalCelsius: null,
    });
});

test("absent and truncated resolver output publishes no sensor", () => {
    assert.equal(parseSensorLine(""), null);
    assert.equal(parseSensorLine("coretemp\tPackage id 0\t/sys/class/hwmon/hwmon7/temp1_input\n"), null);
});

test("hwmon millidegrees are rounded to whole degrees", () => {
    assert.equal(parseTemperature("55000\n"), 55);
    assert.equal(parseTemperature("55600\n"), 56);
});

test("unavailable temperature is null rather than zero", () => {
    for (const text of ["", "0\n", "not-a-temperature\n"])
        assert.equal(parseTemperature(text), null);
});
