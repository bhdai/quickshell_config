/**
 * When a current reading is in warning state: at or above the threshold its own metric was
 * given, and out of it again on the next reading that is not.
 *
 * One module for all four cards, because "under pressure" has to mean one thing across a
 * destination that reports on four resources. The thresholds themselves are policy, not
 * measurement, which is why they are stated here once rather than beside the readings that
 * compare against them.
 *
 * Everything here is a function of the reading in hand. There is deliberately no memory of the
 * previous one: debounce would leave the colour describing a moment that has passed, and
 * hysteresis would make a stated threshold mean two different numbers depending on which side
 * the machine approached it from.
 */

.pragma library

// The bar's existing policy, as the 0–1 fractions `ResourceUsage` publishes rather than the
// whole percentages the bar states. Retuning either surface alone would let the bar and the
// destination disagree about the same machine, so `tests/warning-state.test.mjs` compares
// these against the bar's own numbers.
const CPU_USAGE = 0.9;
const MEMORY_USAGE = 0.9;
const SWAP_USAGE = 0.8;

// Dashboard policy: this reading is on no other surface.
const STORAGE_OCCUPANCY = 0.9;

// Temperature has no threshold of its own — every machine reports the limit of the part the
// sensor sits on, and the warning has to arrive before that limit rather than at it.
const TEMPERATURE_CRITICAL_FRACTION = 0.9;

/**
 * `reading` is a current value in the threshold's own units. Anything that is not a finite
 * number is a reading the machine has not taken — `null` before the first one, `NaN` for a
 * sample that could not be measured — and an absent reading is not an alarming one.
 */
function atThreshold(reading, threshold) {
    return typeof reading === "number" && Number.isFinite(reading) && reading >= threshold;
}

/**
 * Both arguments are degrees Celsius, `criticalCelsius` being the machine's own hwmon limit.
 * A machine that reported no limit — or a sensor claiming one at or below zero, which would
 * put every temperature it can read in warning state — has no threshold to be measured
 * against, so its temperature can never warn.
 */
function temperatureWarning(celsius, criticalCelsius) {
    const known = typeof criticalCelsius === "number" && Number.isFinite(criticalCelsius) && criticalCelsius > 0;
    if (!known)
        return false;
    return atThreshold(celsius, criticalCelsius * TEMPERATURE_CRITICAL_FRACTION);
}
