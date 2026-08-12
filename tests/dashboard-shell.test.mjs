import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { blocks, read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const barDir = path.join(repoRoot, "modules", "bar");
const dashboardDir = path.join(repoRoot, "modules", "dashboard");

const dashboard = read(dashboardDir, "Dashboard.qml");
const dashTabBar = read(dashboardDir, "DashTabBar.qml");
const calendarCard = read(dashboardDir, "CalendarCard.qml");
const weather = read(repoRoot, "services", "Weather.qml");

// `qs ipc call` cannot distinguish a missing target from a handler that failed, so scripts
// have nothing to read but what the handler returns.
test("every dashboard IPC handler answers with a string", () => {
    const [handler] = blocks(dashboard, "IpcHandler");

    assert.match(handler, /target: "dashboard"/);
    assert.match(handler, /function toggle\(\): string/);
    assert.match(handler, /function open\(tab: string\): string/);
    assert.match(handler, /function close\(\): string/);
    assert.match(handler, /return "closed"/);
    assert.match(handler, /return "opened " \+ canonicalTab/);
});

test("an unknown tab is named back rather than opened", () => {
    const [open] = blocks(dashboard, "function open(tab: string): string");

    const rejection = open.indexOf('return "unknown tab: " + tab');
    assert.notEqual(rejection, -1, "open() does not name an unknown tab back");
    assert.ok(rejection < open.indexOf("root.currentTab = canonicalTab"), "open() selects an unknown tab");
    assert.ok(rejection < open.indexOf("isOpen = true"), "open() opens before it validates the tab");
});

test("the calendar alias is canonical before open changes state or answers", () => {
    const [open] = blocks(dashboard, "function open(tab: string): string");

    const canonical = open.indexOf('const canonicalTab = tab === "calendar" ? "dashboard" : tab');
    const validation = open.indexOf("root.knows(canonicalTab)");
    const selection = open.indexOf("root.currentTab = canonicalTab");
    const response = open.indexOf('return "opened " + canonicalTab');

    assert.notEqual(canonical, -1, "open() does not retain the calendar alias");
    assert.ok(canonical < open.indexOf('return "unknown tab: " + tab'), "open() can answer before resolving the alias");
    assert.ok(canonical < validation, "open() validates before resolving the alias");
    assert.ok(validation < selection, "open() changes selection before validation");
    assert.ok(selection < response, "open() answers before selecting the canonical destination");
});

// Identity and presentation share one ordered model, but the key is never recovered from
// label text. A presentation rename therefore cannot move the IPC surface.
test("destination keys are ordered independently of their labels", () => {
    assert.match(dashboard, /readonly property var tabs: \[\s*\{ key: "dashboard", label: "Dashboard", icon: "dashboard" \},\s*\{ key: "wallpaper", label: "Wallpaper", icon: "wallpaper" \},\s*\{ key: "performance", label: "Performance", icon: "speed" \}\s*\]/);
    assert.match(dashboard, /function knows\(tab: string\): bool \{\s*return root\.tabs\.some\(destination => destination\.key === tab\);/);
    assert.doesNotMatch(dashboard, /toLowerCase/);
    assert.match(dashTabBar, /root\.current === modelData\.key/);
    assert.match(dashTabBar, /root\.selected\(tab\.modelData\.key\)/);
    assert.match(dashTabBar, /text: tab\.modelData\.label/);
    assert.doesNotMatch(dashTabBar, /toLowerCase/);
});

test("the bar toggle closes in place or opens on the Dashboard destination", () => {
    const [toggle] = blocks(dashboard, "function toggle(): void");

    const close = toggle.indexOf("root.isOpen = false");
    const earlyReturn = toggle.indexOf("return;");
    const selection = toggle.indexOf('root.currentTab = "dashboard"');

    assert.ok(close < earlyReturn && earlyReturn < selection, "toggle() changes destination while closing");
    assert.match(toggle, /root\.currentTab = "dashboard";\s*root\.isOpen = true;/);
});

test("opening the dashboard refreshes readings that are already stale", () => {
    assert.match(dashboard, /onIsOpenChanged: \{\s*if \(root\.isOpen\)\s*Weather\.refreshIfStale\(\);/);
});

test("the popup the dashboard replaces is gone", () => {
    for (const retired of ["DateTimePopup.qml", "CalendarWidget.qml", "WeatherWidget.qml", "calendar_layout.js"])
        assert.equal(existsSync(path.join(barDir, retired)), false, `modules/bar/${retired} still exists`);
});

test("the bar clock drives the one dashboard rather than owning a popup", () => {
    const clock = read(barDir, "TimeWidget.qml");
    const bar = read(barDir, "Bar.qml");

    assert.match(clock, /required property Dashboard dashboard/);
    assert.match(clock, /root\.dashboard\.toggle\(\)/);

    const [, id] = bar.match(/Dashboard \{\s*id: (\w+)\s*\}/) ?? [];
    assert.ok(id, "the bar does not declare one Dashboard");
    // An object's own scope wins over the file's ids, so an id matching the property name
    // makes `dashboard: dashboard` bind the widget to itself and hold null. That is a
    // binding-loop warning and five throwing bindings, not a load failure, so nothing else
    // in the suite would notice.
    assert.notEqual(id, "dashboard", "the Dashboard id shadows TimeWidget's own property");
    assert.match(bar, new RegExp(`TimeWidget \\{\\s*dashboard: ${id}\\s*\\}`));
});

// The bar already shows the time the click came from, so the popup no longer repeats it.
test("the duplicated clock is gone and uptime moved to the battery readout", () => {
    assert.doesNotMatch(calendarCard, /Time\.hoursMinutes/);
    assert.doesNotMatch(calendarCard, /Time\.uptime/);
    assert.match(read(barDir, "BatteryDetails.qml"), /text: Time\.uptime/);
});

test("a day cell is a ripple and nothing else", () => {
    const [cell] = blocks(calendarCard, "delegate: RippleButton");

    assert.match(cell, /toggled: isToday/);
    assert.doesNotMatch(cell, /onClicked/);
    assert.doesNotMatch(cell, /selected/i);
});

// Visibility-gating it would let the grid above move by 28px on every month navigation,
// against a card that cannot change height.
test("the Today control keeps its row while it is inactive", () => {
    const today = blocks(calendarCard, "RippleButton").find(block => block.includes("id: todayButton"));
    assert.ok(today, "the calendar has no Today control");

    assert.match(today, /opacity: root\.monthShift !== 0 \? 1 : 0/);
    assert.match(today, /enabled: root\.monthShift !== 0/);
    assert.doesNotMatch(today, /visible:/);
    assert.doesNotMatch(today, /Layout\.topMargin/);
});

test("the request asks for exactly what the card shows, for one day, with no hourly data", () => {
    const [request] = weather.match(/const url = [\s\S]*?;\n/);

    // uv_index rides in `current`, not as the daily uv_index_max: the max is the solar-noon
    // peak, which left the tile reading the afternoon's number long after dark.
    assert.match(request, /current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,uv_index/);
    assert.match(request, /daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,sunrise,sunset/);
    assert.match(request, /forecast_days=1/);
    assert.match(request, /timezone=auto/);
    assert.doesNotMatch(request, /hourly/);
});

test("the removed forecast behaviour left no state behind", () => {
    for (const gone of ["weeklyForecast", "hourlyForecast", "rawHourlyData", "rawDailyData", "selectedDayIndex", "selectDay", "getHourlyForDay"])
        assert.doesNotMatch(weather, new RegExp(gone), `Weather still carries ${gone}`);
});

test("readings are typed numbers and dates, not unit-bearing strings", () => {
    for (const declaration of [
        /property real temperature: NaN/,
        /property real apparentTemperature: NaN/,
        /property real humidity: NaN/,
        /property real dewPoint: NaN/,
        /property int weatherCode: -1/,
        /property bool isDay: true/,
        /property real windSpeed: NaN/,
        /property real windDirection: NaN/,
        /property real high: NaN/,
        /property real low: NaN/,
        /property real precipitationSum: NaN/,
        /property real precipitationProbability: NaN/,
        /property real uvIndex: NaN/,
        /property var sunrise: null/,
        /property var sunset: null/,
        /property date lastUpdated: new Date\(0\)/
    ])
        assert.match(weather, declaration);
});

// Presentation policy lives in the tested library; the service is lifecycle only.
test("the service maps nothing the format library already maps", () => {
    assert.match(weather, /import "weather_format\.js" as WeatherFormat/);
    for (const gone of ["getWmoDescription", "getWeatherIcon", "°C", "km/h"])
        assert.doesNotMatch(weather, new RegExp(gone), `Weather still formats ${gone} itself`);
});

test("the location is two named numbers with no configuration surface around them", () => {
    assert.match(weather, /readonly property real latitude: 21\.0285/);
    assert.match(weather, /readonly property real longitude: 105\.8042/);
    assert.doesNotMatch(weather, /property string city/);

    // The WHY the coordinates need, since a bare pair of numbers says none of it.
    const [preamble] = weather.match(/\/\/ Hanoi\.[\s\S]*?readonly property real latitude/);
    assert.match(preamble, /timezone=auto/);
});

test("refresh, retry and staleness all read the frozen constants", () => {
    assert.match(weather, /WeatherFormat\.REFRESH_IF_OLDER_MS/);
    assert.match(weather, /WeatherFormat\.RETRY_DELAYS_MS\[root\.retryAttempt\]/);
    assert.match(weather, /interval: WeatherFormat\.BACKGROUND_INTERVAL_MS/);
});

test("a fetch cannot overlap another, and the retry ladder is bounded", () => {
    const [refresh] = blocks(weather, "function refresh(): void");
    const [failure] = blocks(weather, "function recordFailure(reason: string): void");

    assert.match(refresh, /if \(fetcher\.running\)\s*return;/);
    assert.match(failure, /if \(root\.retryAttempt >= WeatherFormat\.RETRY_DELAYS_MS\.length\)\s*return;/);
});

test("a failed fetch leaves the last good readings standing", () => {
    const [failure] = blocks(weather, "function recordFailure(reason: string): void");

    assert.doesNotMatch(failure, /hasData/);
    assert.doesNotMatch(failure, /lastUpdated/);
});
