/**
 * What the battery body draws for a given power state: the trailing glyph, and whether the
 * fill reads as "on wall power".
 *
 * Three states, not two. A charge threshold (this machine stops at 70%) parks the battery in
 * UPower's `pending-charge` for most of its plugged-in life: wall power is connected, the
 * percentage will not drop, and yet no current is flowing. Collapsing that into "charging"
 * lights the bolt permanently and costs the bolt its meaning; collapsing it into
 * "discharging" tells you to go find a charger you are already plugged into.
 *
 * The two questions are answered by different channels rather than both by the glyph. The fill
 * colour answers "will this number drop?", so it is on for every plugged-in state. The glyph
 * answers "is energy moving?", so it is the bolt only while current actually flows and the
 * battery's own nob the rest of the time. Held-at-threshold is therefore a green battery that
 * looks like a battery — no third symbol, because a symbol for "nothing is happening" is
 * something to look at rather than something to read, and the hover readout already says it
 * in words.
 *
 * Callers pass state in rather than reading the Battery singleton, so the rule is one function
 * of its inputs and `tests/battery-glyph.test.mjs` can hold it to that.
 */

.pragma library

var Glyph = {
    // The battery's own terminal cap. Drawn whenever there is nothing to say about power flow.
    Nob: "nob",
    Bolt: "bolt",
};

/**
 * `state` carries `isCharging` and `percentage` (0–1). `isPluggedIn` is deliberately not
 * consulted: being attached to power is the fill's business, not the glyph's.
 */
function pickGlyph(state) {
    // A full battery has nothing left to say about direction, and the bolt beside a bar that
    // cannot rise reads as a stuck indicator rather than as activity.
    if (state.percentage >= 1)
        return Glyph.Nob;
    return state.isCharging ? Glyph.Bolt : Glyph.Nob;
}

/**
 * Whether the fill takes the charging colour: true whenever wall power is attached, including
 * while charging is held at the threshold. It is the same question in both states — the number
 * is not going to drop — so it is the same colour.
 */
function usesChargingFill(state) {
    return state.isPluggedIn;
}

/**
 * The nob is the glyph only when `pickGlyph` says so; it is filled once there is no headroom
 * left, which is the one case where a full bar and a full cap agree.
 */
function nobFilled(state) {
    return state.percentage >= 1;
}
