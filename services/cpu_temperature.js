.pragma library

// Parses the tab-separated channel selected by the resolver. An absent critical value
// does not invalidate an otherwise usable sensor.
function parseSensorLine(stdout) {
    const fields = String(stdout ?? "").replace(/\r?\n$/, "").split("\t");
    if (fields.length !== 4 || !fields[0] || !fields[2])
        return null;

    const critical = Number(fields[3]);
    return {
        chip: fields[0],
        label: fields[1],
        path: fields[2],
        criticalCelsius: fields[3] && Number.isFinite(critical) && critical > 0
            ? Math.round(critical / 1000)
            : null
    };
}

// Converts one hwmon millidegree reading to the whole-degree resolution consumers use.
function parseTemperature(text) {
    const value = Number(String(text ?? "").trim());
    if (!String(text ?? "").trim() || !Number.isFinite(value) || value <= 0)
        return null;
    return Math.round(value / 1000);
}
