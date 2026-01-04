pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Hanoi coordinates
    readonly property real lat: 21.0285
    readonly property real lng: 105.8042
    readonly property string city: "Hanoi"
    readonly property int fetchInterval: 1800000 // 30 minutes

    property var currentData: ({
            temp: "--",
            min: "--",
            max: "--",
            condition: "",
            weatherCode: 0,
            city: "Hanoi",
            humidity: "--",
            wind: "--",
            windDir: ""
        })

    property var hourlyForecast: []
    property var weeklyForecast: []

    // Map WMO weather codes (0-99) to text
    function getWmoDescription(code) {
        const c = parseInt(code);
        if (c === 0)
            return "Clear sky";
        if (c === 1)
            return "Mainly clear";
        if (c === 2)
            return "Partly cloudy";
        if (c === 3)
            return "Overcast";
        if (c === 45 || c === 48)
            return "Fog";
        if (c >= 51 && c <= 55)
            return "Drizzle";
        if (c >= 56 && c <= 57)
            return "Freezing Drizzle";
        if (c >= 61 && c <= 65)
            return "Rain";
        if (c >= 66 && c <= 67)
            return "Freezing Rain";
        if (c >= 71 && c <= 75)
            return "Snow fall";
        if (c === 77)
            return "Snow grains";
        if (c >= 80 && c <= 82)
            return "Rain showers";
        if (c >= 85 && c <= 86)
            return "Snow showers";
        if (c >= 95 && c <= 99)
            return "Thunderstorm";
        return "Unknown";
    }

    // Map WMO codes to Google Weather SVG icons
    // isDay: 1 = day, 0 = night (from API is_day field)
    function getWeatherIcon(code, isDay) {
        const c = parseInt(code);
        const day = (isDay !== undefined && isDay !== null) ? isDay : 1;

        // Clear sky
        if (c === 0)
            return day ? "clear_day.svg" : "clear_night.svg";
        // Mainly clear
        if (c === 1)
            return day ? "mostly_clear_day.svg" : "mostly_clear_night.svg";
        // Partly cloudy
        if (c === 2)
            return day ? "partly_cloudy_day.svg" : "partly_cloudy_night.svg";
        // Overcast
        if (c === 3)
            return "cloudy.svg";
        // Fog
        if (c === 45 || c === 48)
            return "haze_fog_dust_smoke.svg";
        // Drizzle (light, moderate, dense)
        if (c >= 51 && c <= 55)
            return "drizzle.svg";
        // Freezing drizzle
        if (c === 56 || c === 57)
            return "icy.svg";
        // Rain - slight
        if (c === 61)
            return day ? "scattered_showers_day.svg" : "scattered_showers_night.svg";
        // Rain - moderate
        if (c === 63)
            return "showers_rain.svg";
        // Rain - heavy
        if (c === 65)
            return "heavy_rain.svg";
        // Freezing rain
        if (c === 66 || c === 67)
            return "mixed_rain_hail_sleet.svg";
        // Snow - slight
        if (c === 71)
            return "flurries.svg";
        // Snow - moderate
        if (c === 73)
            return "showers_snow.svg";
        // Snow - heavy
        if (c === 75)
            return "heavy_snow.svg";
        // Snow grains
        if (c === 77)
            return "sleet_hail.svg";
        // Rain showers - slight
        if (c === 80)
            return day ? "scattered_showers_day.svg" : "scattered_showers_night.svg";
        // Rain showers - moderate
        if (c === 81)
            return "showers_rain.svg";
        // Rain showers - violent
        if (c === 82)
            return "heavy_rain.svg";
        // Snow showers - slight
        if (c === 85)
            return day ? "scattered_snow_showers_day.svg" : "scattered_snow_showers_night.svg";
        // Snow showers - heavy
        if (c === 86)
            return "showers_snow.svg";
        // Thunderstorm
        if (c === 95)
            return "isolated_thunderstorms.svg";
        // Thunderstorm with hail
        if (c === 96 || c === 99)
            return "strong_thunderstorms.svg";

        // Fallback
        return "cloudy.svg";
    }

    function getData() {
        // Open-Meteo URL
        // hourly: temp, weathercode, is_day
        // daily: weathercode, max temp, min temp
        // current: temp, humidity, weathercode, windspeed, is_day
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lng + "&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,is_day" + "&hourly=temperature_2m,weather_code,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min" + "&timezone=auto&forecast_days=14";

        const command = "curl -s '" + url + "'";
        fetcher.command = ["bash", "-c", command];
        fetcher.running = true;
    }

    function refineData(data) {
        try {
            // Current Weather
            const current = data.current;
            currentData = {
                temp: Math.round(current.temperature_2m) + "°C",
                humidity: current.relative_humidity_2m + "%",
                wind: current.wind_speed_10m + " km/h",
                windDir: "" // Open-Meteo gives degrees, simpler to omit or convert later if really needed
                ,
                weatherCode: current.weather_code,
                condition: getWmoDescription(current.weather_code),
                isDay: current.is_day,
                city: root.city
            };

            // Hourly Forecast
            // api returns structure: hourly: { time: [...], temperature_2m: [...], ... }
            const hourly = data.hourly;
            const currentHourIso = new Date().toISOString().substring(0, 13); // "2024-01-01T12"

            const hourlyData = [];
            // Find start index (approximate, since API returns ISO strings)
            let startIndex = 0;
            const now = new Date();
            const currentHour = now.getHours();

            // Loop to find the index matching current hour (by simple string match for robustness)
            for (let i = 0; i < hourly.time.length; i++) {
                // time format: "2024-01-01T14:00"
                const tStr = hourly.time[i];
                // Extract hour part locally "T14:00" -> 14
                const parts = tStr.split("T");
                if (parts.length < 2)
                    continue;

                const dayStr = parts[0]; // "2024-01-01"
                const hourPart = parseInt(parts[1].split(":")[0]);

                // Compare with local 'now' components
                // Note: date string comparison simplistic but sufficient for "today"
                // Ideally construct date:
                const d = new Date(tStr);

                if (d.getDate() === now.getDate() && d.getHours() === currentHour) {
                    startIndex = i;
                    break;
                }
            }

            // Get 7 items (Next 21 hours) to make total 8 (Current + 7)
            for (let i = 0; i < 7; i++) {
                const targetIndex = startIndex + ((i + 1) * 3);

                if (targetIndex >= hourly.time.length)
                    break;

                const timeStr = hourly.time[targetIndex]; // "2024-01-01T14:00"
                const dateObj = new Date(timeStr);
                const hour = dateObj.getHours();
                const temp = Math.round(hourly.temperature_2m[targetIndex]);
                const code = hourly.weather_code[targetIndex];

                const isDay = hourly.is_day[targetIndex];
                hourlyData.push({
                    time: hour + ":00",
                    temp: temp + "°",
                    weatherCode: code,
                    isDay: isDay,
                    icon: getWeatherIcon(code, isDay)
                });
            }
            root.hourlyForecast = hourlyData;

            // Daily Forecast (7 days)
            const daily = data.daily;
            const dailyData = [];

            // Note: daily arrays aligned by index
            for (let i = 0; i < Math.min(8, daily.time.length); i++) {
                // i=0 is today, user asked for "next 7 days include current day" -> 8 days total
                const dateStr = daily.time[i];
                const dateObj = new Date(dateStr);
                const dayName = i === 0 ? "Today" : Qt.formatDateTime(dateObj, "ddd");

                dailyData.push({
                    day: dayName,
                    high: Math.round(daily.temperature_2m_max[i]) + "°",
                    low: Math.round(daily.temperature_2m_min[i]) + "°",
                    weatherCode: daily.weather_code[i],
                    icon: getWeatherIcon(daily.weather_code[i], 1)
                });
            }
            root.weeklyForecast = dailyData;
        } catch (e) {
            console.error("Weather (Open-Meteo): Failed to refine data:", e);
        }
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed.error) {
                        console.error("Weather (Open-Meteo) API Error:", parsed.reason);
                        return;
                    }
                    root.refineData(parsed);
                } catch (e) {
                    console.error("Weather: Failed to parse JSON:", e);
                }
            }
        }
    }

    Timer {
        interval: root.fetchInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.getData()
    }
}
