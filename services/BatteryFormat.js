.pragma library

// Material Symbols draws the battery in eight steps: `battery_0_bar` through
// `battery_6_bar`, then `battery_full`. A name outside that set renders as a blank glyph
// rather than as a missing icon, so the level is clamped before it becomes a step.
const BAR_STEPS = 7;

// `percentage` is the 0..1 fraction UPower reports. Charging gets one symbol rather than a
// charging variant per step: while the number beside it is still moving, the level matters
// less than the fact that it is going up.
function pickBatterySymbol({ percentage, charging }) {
    if (charging)
        return "battery_charging_full";

    const level = Math.min(Math.max(percentage || 0, 0), 1);
    const step = Math.round(level * BAR_STEPS);
    return step >= BAR_STEPS ? "battery_full" : `battery_${step}_bar`;
}
