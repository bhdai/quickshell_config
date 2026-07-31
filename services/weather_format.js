/**
 * Presentation policy for the weather service: WMO descriptions, icon selection, compass
 * bearings, UV bands, staleness wording, and the number formatting the dashboard tiles
 * render. Weather.qml owns the process and the lifecycle; nothing here touches either, so
 * all of it is reachable from `node --test`.
 *
 * Every formatter accepts a value the service does not have yet and answers PLACEHOLDER or
 * an empty caption, so a first load before the first successful fetch keeps its layout.
 */

.pragma library

// #96 froze these. The background tick, how stale a reading has to be for opening the
// dashboard to refetch, the bounded retry ladder after a failure, and the age at which a
// surviving last-good reading admits how old it is.
const BACKGROUND_INTERVAL_MS = 1800000;
const REFRESH_IF_OLDER_MS = 600000;
const RETRY_DELAYS_MS = [30000, 120000, 300000];
const STALE_AGE_MS = 3600000;

const PLACEHOLDER = "--";

const COMPASS_POINTS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];

const WMO_DESCRIPTIONS = {
    0: "Clear sky",
    1: "Mostly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Rime fog",
    51: "Light drizzle",
    53: "Drizzle",
    55: "Dense drizzle",
    56: "Light freezing drizzle",
    57: "Freezing drizzle",
    61: "Light rain",
    63: "Rain",
    65: "Heavy rain",
    66: "Light freezing rain",
    67: "Heavy freezing rain",
    71: "Light snow",
    73: "Snow",
    75: "Heavy snow",
    77: "Snow grains",
    80: "Light rain showers",
    81: "Rain showers",
    82: "Heavy rain showers",
    85: "Light snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with hail",
    99: "Thunderstorm with heavy hail"
};

function isNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function describeCode(code) {
    const description = WMO_DESCRIPTIONS[parseInt(code)];
    return description === undefined ? "Unknown" : description;
}

/**
 * The asset filename for a WMO code. `isDay` is Open-Meteo's `is_day` flag; only the codes
 * with a distinct night rendering read it, and an absent flag means daytime.
 *
 * Every name this can return must exist under assets/icons/weather — the test walks all
 * hundred codes to hold that.
 */
function iconFor(code, isDay) {
    const c = parseInt(code);
    const day = (isDay === undefined || isDay === null) ? 1 : isDay;

    if (c === 0)
        return day ? "clear_day.svg" : "clear_night.svg";
    if (c === 1)
        return day ? "mostly_clear_day.svg" : "mostly_clear_night.svg";
    if (c === 2)
        return day ? "partly_cloudy_day.svg" : "partly_cloudy_night.svg";
    if (c === 3)
        return "cloudy.svg";
    if (c === 45 || c === 48)
        return "haze_fog_dust_smoke.svg";
    if (c === 51)
        return "drizzle.svg";
    if (c >= 53 && c <= 55)
        return day ? "scattered_showers_day.svg" : "scattered_showers_night.svg";
    if (c === 56)
        return "icy.svg";
    if (c === 57)
        return "mixed_rain_hail_sleet.svg";
    if (c === 61)
        return day ? "scattered_showers_day.svg" : "scattered_showers_night.svg";
    if (c === 63)
        return "showers_rain.svg";
    if (c === 65)
        return "heavy_rain.svg";
    if (c === 66)
        return "mixed_rain_snow.svg";
    if (c === 67)
        return "mixed_rain_hail_sleet.svg";
    if (c === 71 || c === 77)
        return "flurries.svg";
    if (c === 73)
        return "showers_snow.svg";
    if (c === 75)
        return "heavy_snow.svg";
    if (c === 80 || c === 81)
        return day ? "scattered_showers_day.svg" : "scattered_showers_night.svg";
    if (c === 82)
        return "heavy_rain.svg";
    if (c === 85)
        return day ? "scattered_snow_showers_day.svg" : "scattered_snow_showers_night.svg";
    if (c === 86)
        return "heavy_snow.svg";
    if (c === 95)
        return "isolated_thunderstorms.svg";
    if (c === 96 || c === 99)
        return "strong_thunderstorms.svg";

    return "cloudy.svg";
}

/**
 * Sixteen-point bearing. Each point owns half a step either side of its own bearing, so N
 * runs from 348.75 through 11.25 and the modulo has to happen after the rounding.
 */
function compass(degrees) {
    if (!isNumber(degrees))
        return "";
    const step = Math.round(degrees / 22.5);
    return COMPASS_POINTS[((step % 16) + 16) % 16];
}

function describeUv(uv) {
    if (!isNumber(uv))
        return "";
    if (uv < 3)
        return "low";
    if (uv < 6)
        return "moderate";
    if (uv < 8)
        return "high";
    if (uv < 11)
        return "very high";
    return "extreme";
}

/**
 * The eleven-point WHO scale compressed to the tile's five dots: one dot per band, so the
 * lit run says which band today sits in rather than being a bare eleventh of the number.
 */
function uvSteps(uv) {
    if (!isNumber(uv) || uv < 1)
        return 0;
    if (uv < 3)
        return 1;
    if (uv < 6)
        return 2;
    if (uv < 8)
        return 3;
    if (uv < 11)
        return 4;
    return 5;
}

/**
 * How the card admits its readings are old. Empty until STALE_AGE_MS, so an ordinary
 * between-ticks gap says nothing. `lastUpdated` of 0 is "no reading has ever arrived",
 * which the placeholders already say.
 */
function staleNotice(lastUpdated, now) {
    if (!isNumber(lastUpdated) || lastUpdated <= 0)
        return "";
    const age = now - lastUpdated;
    if (age < STALE_AGE_MS)
        return "";

    const hours = Math.floor(age / 3600000);
    if (hours < 24)
        return "updated " + hours + "h ago";
    return "updated " + Math.floor(hours / 24) + "d ago";
}

function formatTemperature(celsius) {
    return isNumber(celsius) ? String(Math.round(celsius)) : PLACEHOLDER;
}

function formatPercent(value) {
    return isNumber(value) ? String(Math.round(value)) : PLACEHOLDER;
}

// A bare index with no unit after it, such as UV.
function formatIndex(value) {
    return isNumber(value) ? String(Math.round(value)) : PLACEHOLDER;
}

function formatSpeed(kmh) {
    return isNumber(kmh) ? String(Math.round(kmh)) : PLACEHOLDER;
}

function formatPrecipitation(mm) {
    return isNumber(mm) ? mm.toFixed(1) : PLACEHOLDER;
}

function formatClock(date) {
    if (!date || isNaN(date.getTime()))
        return PLACEHOLDER;
    const minutes = date.getMinutes();
    return date.getHours() + ":" + (minutes < 10 ? "0" + minutes : String(minutes));
}

function apparentCaption(apparent, actual) {
    if (!isNumber(apparent) || !isNumber(actual))
        return "";
    const delta = Math.round(apparent) - Math.round(actual);
    if (delta === 0)
        return "as it reads";
    return Math.abs(delta) + "° " + (delta > 0 ? "warmer" : "cooler");
}

function humidityCaption(humidity) {
    if (!isNumber(humidity))
        return "";
    if (humidity < 30)
        return "dry";
    if (humidity < 60)
        return "comfortable";
    if (humidity < 80)
        return "humid";
    return "very humid";
}

function windCaption(degrees) {
    if (!isNumber(degrees))
        return "";
    return "from " + compass(degrees) + " · " + Math.round(degrees) + "°";
}

function precipitationCaption(probability) {
    if (!isNumber(probability))
        return "";
    return Math.round(probability) + "% chance";
}

/**
 * Where now sits between sunrise and sunset, for the sun tile's arc. Clamped, so the dot
 * rests at one end of the arc through the night rather than running off it.
 */
function dayProgress(now, sunrise, sunset) {
    if (!now || !sunrise || !sunset)
        return 0;
    const span = sunset.getTime() - sunrise.getTime();
    if (!isNumber(span) || span <= 0)
        return 0;
    return Math.max(0, Math.min(1, (now.getTime() - sunrise.getTime()) / span));
}
