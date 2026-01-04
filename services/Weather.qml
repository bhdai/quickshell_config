pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string city: "Hanoi"
    readonly property int fetchInterval: 1800000 // 30 minutes

    property var currentData: ({
        temp: "--",
        feelsLike: "--",
        condition: "",
        weatherCode: "113",
        city: "Hanoi",
        humidity: "--",
        wind: "--",
        windDir: ""
    })

    property var hourlyForecast: []
    property var weeklyForecast: []

    function formatCityName(cityName) {
        return cityName.replace(/ /g, "+");
    }

    function getWeatherIcon(code) {
        const codeNum = parseInt(code);
        // Map wttr.in weather codes to Material Symbols
        if (codeNum === 113) return "clear_day";
        if (codeNum === 116) return "partly_cloudy_day";
        if (codeNum === 119 || codeNum === 122) return "cloud";
        if (codeNum >= 176 && codeNum <= 263) return "rainy";
        if (codeNum >= 266 && codeNum <= 299) return "rainy";
        if (codeNum >= 302 && codeNum <= 356) return "rainy";
        if (codeNum >= 359 && codeNum <= 395) return "weather_snowy";
        return "cloud";
    }

    function getData() {
        const formattedCity = formatCityName(city);
        const command = "curl -s 'wttr.in/" + formattedCity + "?format=j1'";
        fetcher.command = ["bash", "-c", command];
        fetcher.running = true;
    }

    function refineData(data) {
        try {
            // Current weather
            const current = data.current_condition[0];
            const location = data.nearest_area[0];

            currentData = {
                temp: current.temp_C + "°C",
                feelsLike: current.FeelsLikeC + "°C",
                condition: current.weatherDesc[0].value,
                weatherCode: current.weatherCode,
                city: location.areaName[0].value,
                humidity: current.humidity + "%",
                wind: current.windspeedKmph + " km/h",
                windDir: current.winddir16Point
            };

            // Hourly forecast (next 8 hours)
            const todayWeather = data.weather[0];
            const tomorrowWeather = data.weather[1];
            const currentHour = new Date().getHours();
            const hourlyData = [];

            // Get remaining hours from today
            for (let i = 0; i < todayWeather.hourly.length; i++) {
                const hourData = todayWeather.hourly[i];
                const hour = parseInt(hourData.time) / 100;
                if (hour >= currentHour && hourlyData.length < 8) {
                    hourlyData.push({
                        time: hour + ":00",
                        temp: hourData.tempC + "°",
                        weatherCode: hourData.weatherCode,
                        icon: getWeatherIcon(hourData.weatherCode)
                    });
                }
            }

            // Fill remaining from tomorrow
            if (hourlyData.length < 8 && tomorrowWeather) {
                for (let i = 0; i < tomorrowWeather.hourly.length && hourlyData.length < 8; i++) {
                    const hourData = tomorrowWeather.hourly[i];
                    const hour = parseInt(hourData.time) / 100;
                    hourlyData.push({
                        time: hour + ":00",
                        temp: hourData.tempC + "°",
                        weatherCode: hourData.weatherCode,
                        icon: getWeatherIcon(hourData.weatherCode)
                    });
                }
            }

            hourlyForecast = hourlyData;

            // Weekly forecast (7 days)
            const weeklyData = [];
            const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

            for (let i = 0; i < Math.min(7, data.weather.length); i++) {
                const dayData = data.weather[i];
                const date = new Date(dayData.date);
                weeklyData.push({
                    day: i === 0 ? "Today" : dayNames[date.getDay()],
                    high: dayData.maxtempC + "°",
                    low: dayData.mintempC + "°",
                    weatherCode: dayData.hourly[4].weatherCode, // Use midday weather
                    icon: getWeatherIcon(dayData.hourly[4].weatherCode)
                });
            }

            weeklyForecast = weeklyData;

        } catch (e) {
            console.error("Weather: Failed to refine data:", e);
        }
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
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
