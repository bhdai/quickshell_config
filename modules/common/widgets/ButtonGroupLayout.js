.pragma library

/**
 * Width allocation for a fixed-width row of equal-width buttons, where holding one button
 * grows it and only its two immediate visible neighbours give the space back.
 *
 * `visibility` holds one flag per row slot; hidden slots are allocated 0 and are skipped
 * when looking for a pressed button's neighbours. `pressedIndex` indexes the same slots
 * (-1 when nothing is held). `pressGrowth` is how much the held button wants to gain.
 *
 * The returned visible widths plus the inter-button spacing always sum back to
 * `totalWidth`, so a press can never resize the row itself. A neighbour is never shrunk
 * past half its resting width, which caps the growth actually granted.
 */
function allocateWidths(visibility, totalWidth, spacing, pressedIndex, pressGrowth) {
    const widths = visibility.map(() => 0);
    const shown = [];
    for (let i = 0; i < visibility.length; ++i) {
        if (visibility[i])
            shown.push(i);
    }
    if (shown.length === 0)
        return widths;

    const base = (totalWidth - spacing * (shown.length - 1)) / shown.length;
    for (const slot of shown)
        widths[slot] = base;

    const position = shown.indexOf(pressedIndex);
    if (position < 0 || pressGrowth <= 0)
        return widths;

    const neighbours = [];
    if (position > 0)
        neighbours.push(shown[position - 1]);
    if (position < shown.length - 1)
        neighbours.push(shown[position + 1]);
    if (neighbours.length === 0)
        return widths;

    const shrink = Math.min(pressGrowth / neighbours.length, base / 2);
    for (const slot of neighbours)
        widths[slot] = base - shrink;
    widths[pressedIndex] = base + shrink * neighbours.length;

    return widths;
}
