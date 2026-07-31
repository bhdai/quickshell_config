import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const weather = loadQmlJs(path.join(repoRoot, "services", "weather_format.js"), [
    "BACKGROUND_INTERVAL_MS",
    "REFRESH_IF_OLDER_MS",
    "RETRY_DELAYS_MS",
    "STALE_AGE_MS",
    "PLACEHOLDER",
    "describeCode",
    "iconFor",
    "compass",
    "describeUv",
    "uvSteps",
    "staleNotice",
    "formatTemperature",
    "formatPercent",
    "formatIndex",
    "formatSpeed",
    "formatPrecipitation",
    "formatClock",
    "apparentCaption",
    "humidityCaption",
    "windCaption",
    "precipitationCaption",
    "dayProgress"
]);

const {
    BACKGROUND_INTERVAL_MS,
    REFRESH_IF_OLDER_MS,
    RETRY_DELAYS_MS,
    STALE_AGE_MS,
    PLACEHOLDER,
    describeCode,
    iconFor,
    compass,
    describeUv,
    uvSteps,
    staleNotice,
    formatTemperature,
    formatPercent,
    formatIndex,
    formatSpeed,
    formatPrecipitation,
    formatClock,
    apparentCaption,
    humidityCaption,
    windCaption,
    precipitationCaption,
    dayProgress
} = weather;

const minutes = n => n * 60000;

// #96 froze these rather than leaving them approximate, because retry and staleness
// behaviour is only repeatable if the numbers are.
test("the refresh, retry and staleness thresholds are the ones the spec froze", () => {
    assert.equal(BACKGROUND_INTERVAL_MS, minutes(30));
    assert.equal(REFRESH_IF_OLDER_MS, minutes(10));
    assert.deepEqual(RETRY_DELAYS_MS, [minutes(0.5), minutes(2), minutes(5)]);
    assert.equal(STALE_AGE_MS, minutes(60));
});

test("every WMO code the API can send has a description", () => {
    assert.equal(describeCode(0), "Clear sky");
    assert.equal(describeCode(3), "Overcast");
    assert.equal(describeCode(45), "Fog");
    assert.equal(describeCode(61), "Light rain");
    assert.equal(describeCode(95), "Thunderstorm");
    assert.equal(describeCode(99), "Thunderstorm with heavy hail");
});

test("an unknown code degrades to a word rather than an empty string", () => {
    assert.equal(describeCode(7), "Unknown");
    assert.equal(describeCode(null), "Unknown");
    assert.equal(describeCode(undefined), "Unknown");
});

test("the sky codes pick a different icon by day and by night", () => {
    for (const code of [0, 1, 2]) {
        const day = iconFor(code, 1);
        const night = iconFor(code, 0);
        assert.notEqual(day, night);
        assert.match(day, /_day\.svg$/);
        assert.match(night, /_night\.svg$/);
    }
});

test("codes with no night variant give the same icon either way", () => {
    for (const code of [3, 45, 48, 65, 95]) {
        assert.equal(iconFor(code, 1), iconFor(code, 0));
    }
});

test("a missing day flag is treated as daytime", () => {
    assert.equal(iconFor(0, undefined), iconFor(0, 1));
    assert.equal(iconFor(0, null), iconFor(0, 1));
});

// A mapper that can name a file the shell does not ship draws an empty box, and only a
// walk of every code it accepts can prove it never does.
test("every icon the mapper can return exists in the weather asset set", () => {
    const icons = new Set();
    for (let code = 0; code <= 99; code++) {
        icons.add(iconFor(code, 1));
        icons.add(iconFor(code, 0));
    }

    for (const icon of icons) {
        assert.match(icon, /^[a-z_]+\.svg$/, `${icon} is not a plain asset filename`);
        assert.ok(existsSync(path.join(repoRoot, "assets", "icons", "weather", icon)), `assets/icons/weather/${icon} is missing`);
    }
});

test("the compass splits the circle into sixteen equal points", () => {
    assert.equal(compass(0), "N");
    assert.equal(compass(90), "E");
    assert.equal(compass(180), "S");
    assert.equal(compass(270), "W");
    assert.equal(compass(45), "NE");
    assert.equal(compass(81), "E");
});

test("each compass point owns half a step either side of its bearing", () => {
    assert.equal(compass(11.24), "N");
    assert.equal(compass(11.25), "NNE");
    assert.equal(compass(33.74), "NNE");
    assert.equal(compass(33.75), "NE");
});

test("the compass wraps rather than falling off either end", () => {
    assert.equal(compass(348.75), "N");
    assert.equal(compass(359.9), "N");
    assert.equal(compass(360), "N");
    assert.equal(compass(370), "N");
    assert.equal(compass(-1), "N");
    assert.equal(compass(-90), "W");
});

test("UV is described on the WHO bands", () => {
    assert.equal(describeUv(0), "low");
    assert.equal(describeUv(2), "low");
    assert.equal(describeUv(3), "moderate");
    assert.equal(describeUv(5), "moderate");
    assert.equal(describeUv(6), "high");
    assert.equal(describeUv(7), "high");
    assert.equal(describeUv(8), "very high");
    assert.equal(describeUv(10), "very high");
    assert.equal(describeUv(11), "extreme");
    assert.equal(describeUv(15), "extreme");
});

test("the five-dot scale lights a dot per band and never overruns", () => {
    assert.equal(uvSteps(0), 0);
    assert.equal(uvSteps(1), 1);
    assert.equal(uvSteps(3), 2);
    assert.equal(uvSteps(6), 3);
    assert.equal(uvSteps(8), 4);
    assert.equal(uvSteps(11), 5);
    assert.equal(uvSteps(15), 5);
    assert.equal(uvSteps(NaN), 0);
});

// Stale data stays on screen; the line is what stops it reading as live.
test("readings say nothing about their age until they are an hour old", () => {
    const now = Date.UTC(2026, 6, 31, 12, 0, 0);

    assert.equal(staleNotice(now, now), "");
    assert.equal(staleNotice(now - minutes(59), now), "");
    assert.equal(staleNotice(now - minutes(60) + 1, now), "");
});

test("an hour-old reading says how old it is", () => {
    const now = Date.UTC(2026, 6, 31, 12, 0, 0);

    assert.equal(staleNotice(now - minutes(60), now), "updated 1h ago");
    assert.equal(staleNotice(now - minutes(119), now), "updated 1h ago");
    assert.equal(staleNotice(now - minutes(120), now), "updated 2h ago");
    assert.equal(staleNotice(now - minutes(60 * 25), now), "updated 1d ago");
    assert.equal(staleNotice(now - minutes(60 * 49), now), "updated 2d ago");
});

test("a reading that never arrived has no age to report", () => {
    const now = Date.UTC(2026, 6, 31, 12, 0, 0);

    assert.equal(staleNotice(0, now), "");
    assert.equal(staleNotice(null, now), "");
    assert.equal(staleNotice(NaN, now), "");
});

test("figures are rounded to the unit they are displayed in", () => {
    assert.equal(formatTemperature(27.4), "27");
    assert.equal(formatTemperature(-0.4), "0");
    assert.equal(formatPercent(93.2), "93");
    assert.equal(formatIndex(6.7), "7");
    assert.equal(formatSpeed(11.6), "12");
    assert.equal(formatPrecipitation(2.44), "2.4");
    assert.equal(formatPrecipitation(0), "0.0");
});

test("a reading the service does not have yet formats as the placeholder", () => {
    assert.equal(PLACEHOLDER, "--");
    for (const format of [formatTemperature, formatPercent, formatIndex, formatSpeed, formatPrecipitation]) {
        assert.equal(format(NaN), PLACEHOLDER);
        assert.equal(format(null), PLACEHOLDER);
        assert.equal(format(undefined), PLACEHOLDER);
    }
    assert.equal(formatClock(null), PLACEHOLDER);
    assert.equal(formatClock(new Date(NaN)), PLACEHOLDER);
});

test("clock times drop the leading zero and keep the twenty-four hour hour", () => {
    assert.equal(formatClock(new Date(2026, 6, 31, 5, 24)), "5:24");
    assert.equal(formatClock(new Date(2026, 6, 31, 18, 32)), "18:32");
    assert.equal(formatClock(new Date(2026, 6, 31, 0, 5)), "0:05");
});

// The tile grammar is a figure over a caption that interprets it; "93%" alone does not
// tell you the day is oppressive.
test("feels-like reports its distance from the actual temperature", () => {
    assert.equal(apparentCaption(33, 27), "6° warmer");
    assert.equal(apparentCaption(24, 27), "3° cooler");
    assert.equal(apparentCaption(27, 27), "as it reads");
    assert.equal(apparentCaption(27.4, 27), "as it reads");
    assert.equal(apparentCaption(NaN, 27), "");
});

test("humidity, wind and precipitation captions interpret their figures", () => {
    assert.equal(humidityCaption(20), "dry");
    assert.equal(humidityCaption(50), "comfortable");
    assert.equal(humidityCaption(75), "humid");
    assert.equal(humidityCaption(93), "very humid");
    assert.equal(humidityCaption(NaN), "");

    assert.equal(windCaption(81), "from E · 81°");
    assert.equal(windCaption(0), "from N · 0°");
    assert.equal(windCaption(NaN), "");

    assert.equal(precipitationCaption(60), "60% chance");
    assert.equal(precipitationCaption(0), "0% chance");
    assert.equal(precipitationCaption(NaN), "");
});

test("the sun's position is a clamped fraction of the daylight span", () => {
    const sunrise = new Date(2026, 6, 31, 6, 0);
    const sunset = new Date(2026, 6, 31, 18, 0);

    assert.equal(dayProgress(new Date(2026, 6, 31, 6, 0), sunrise, sunset), 0);
    assert.equal(dayProgress(new Date(2026, 6, 31, 12, 0), sunrise, sunset), 0.5);
    assert.equal(dayProgress(new Date(2026, 6, 31, 18, 0), sunrise, sunset), 1);
    assert.equal(dayProgress(new Date(2026, 6, 31, 3, 0), sunrise, sunset), 0);
    assert.equal(dayProgress(new Date(2026, 6, 31, 23, 0), sunrise, sunset), 1);
    assert.equal(dayProgress(new Date(2026, 6, 31, 12, 0), null, sunset), 0);
});
