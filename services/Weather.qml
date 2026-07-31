pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "weather_format.js" as WeatherFormat

/**
 * Current conditions and today's one-day outlook from Open-Meteo.
 *
 * Values are typed numbers and dates, never unit-bearing strings: weather_format.js turns
 * them into what the dashboard renders, so nothing has to strip a unit back out of a
 * string to reason about a reading.
 *
 * A failed fetch changes nothing but `hasData` stays as it was — the last good readings
 * survive, and the card admits their age once staleNotice() starts answering.
 */
Singleton {
    id: root

    // Hanoi. Editing these two numbers is the supported way to move the shell somewhere
    // else; there is deliberately no city property, label, or settings surface for a value
    // that changes about once a decade. `timezone=auto` in the request follows these
    // coordinates rather than the machine's clock, so sunrise, sunset and the day/night
    // flag stay consistent with the place named here even from another timezone.
    readonly property real latitude: 21.0285
    readonly property real longitude: 105.8042

    // False until the first successful fetch. The dashboard keeps its placeholders and its
    // layout until it turns true, and it never goes back to false.
    property bool hasData: false

    property real temperature: NaN
    property real apparentTemperature: NaN
    property real humidity: NaN
    property int weatherCode: -1
    property bool isDay: true
    property real windSpeed: NaN
    property real windDirection: NaN

    property real high: NaN
    property real low: NaN
    property real precipitationSum: NaN
    property real precipitationProbability: NaN
    property real uvIndex: NaN
    property var sunrise: null
    property var sunset: null

    property date lastUpdated: new Date(0)

    // Which retry delay comes next. Reset by every success, so a recovered fetch gets the
    // full ladder again rather than going straight to the longest wait.
    property int retryAttempt: 0
    property bool awaitingResponse: false

    function refresh(): void {
        // One request at a time. Retries and the background tick share this guard, so they
        // cannot overlap however they interleave.
        if (fetcher.running)
            return;

        retryTimer.stop();
        root.awaitingResponse = true;

        const url = "https://api.open-meteo.com/v1/forecast" + "?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m" + "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,uv_index_max,sunrise,sunset" + "&forecast_days=1" + "&timezone=auto";

        // Bounded, because the single-request guard above would otherwise let one wedged
        // connection block every retry and every background tick behind it.
        fetcher.command = ["curl", "-s", "--max-time", "20", url];
        fetcher.running = true;
    }

    // What the dashboard calls when it opens: current enough is left alone.
    function refreshIfStale(): void {
        if (!root.hasData || (Date.now() - root.lastUpdated.getTime()) >= WeatherFormat.REFRESH_IF_OLDER_MS)
            root.refresh();
    }

    function accept(payload: string): void {
        if (!root.awaitingResponse)
            return;
        root.awaitingResponse = false;

        let data;
        try {
            data = JSON.parse(payload);
        } catch (e) {
            root.recordFailure("could not parse the response");
            return;
        }

        if (data.error) {
            root.recordFailure(data.reason);
            return;
        }

        const current = data.current;
        const daily = data.daily;
        if (!current || !daily) {
            root.recordFailure("the response carried no readings");
            return;
        }

        root.temperature = current.temperature_2m;
        root.apparentTemperature = current.apparent_temperature;
        root.humidity = current.relative_humidity_2m;
        root.weatherCode = current.weather_code;
        root.isDay = current.is_day === 1;
        root.windSpeed = current.wind_speed_10m;
        root.windDirection = current.wind_direction_10m;

        // forecast_days=1, so every daily array holds exactly today.
        root.high = daily.temperature_2m_max[0];
        root.low = daily.temperature_2m_min[0];
        root.precipitationSum = daily.precipitation_sum[0];
        root.precipitationProbability = daily.precipitation_probability_max[0];
        root.uvIndex = daily.uv_index_max[0];
        // Open-Meteo returns these in the location's own timezone with no offset, which
        // JavaScript reads as local time — the same reading the rest of the shell uses.
        root.sunrise = new Date(daily.sunrise[0]);
        root.sunset = new Date(daily.sunset[0]);

        root.lastUpdated = new Date();
        root.hasData = true;
        root.retryAttempt = 0;
    }

    // Last good readings are left exactly as they are. The retry ladder is bounded: after
    // the last delay the service waits for the next background tick rather than hammering.
    function recordFailure(reason: string): void {
        root.awaitingResponse = false;
        console.warn("Weather: fetch failed:", reason);

        if (root.retryAttempt >= WeatherFormat.RETRY_DELAYS_MS.length)
            return;

        retryTimer.interval = WeatherFormat.RETRY_DELAYS_MS[root.retryAttempt];
        root.retryAttempt++;
        retryTimer.restart();
    }

    Process {
        id: fetcher

        stdout: StdioCollector {
            onStreamFinished: root.accept(text)
        }

        // Only reached when curl produced no parseable output of its own — a response
        // already accepted above clears the guard, so this cannot schedule a second retry.
        onExited: exitCode => {
            if (exitCode !== 0)
                root.recordFailure("curl exited with " + exitCode);
        }
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: WeatherFormat.BACKGROUND_INTERVAL_MS
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
