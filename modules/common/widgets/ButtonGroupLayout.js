.pragma library

/**
 * Width allocation for a fixed-width row of equal-width buttons, where holding one button
 * grows it and only its two immediate visible neighbours give the space back.
 *
 * `visibility` holds one flag per row slot; hidden slots are allocated 0 and are skipped
 * when looking for a pressed button's neighbours. `pressedIndex` indexes the same slots
 * (-1 when nothing is held). `pressGrowth` is what a button with a neighbour on either side
 * gains; one at the row's edge borrows from its single side only and so gains half that.
 *
 * `pressGrowth` arrives already scaled by the press animation's progress, so this runs once
 * per frame and every frame has to hold the row together.
 *
 * The returned widths are whole pixels that, with the inter-button spacing, always sum back
 * to `totalWidth` — a press can never resize the row or nudge a button it did not touch. A
 * neighbour is never shrunk past half its resting width, which caps the growth granted.
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
    const neighbours = [];
    if (position >= 0 && pressGrowth > 0) {
        if (position > 0)
            neighbours.push(shown[position - 1]);
        if (position < shown.length - 1)
            neighbours.push(shown[position + 1]);
    }
    if (neighbours.length > 0) {
        // Growth is per side. A button at the row's edge has only one side to borrow from,
        // so it grows half as much rather than taking a double helping out of its single
        // neighbour, which read as a shove.
        const shrink = Math.min(pressGrowth / 2, base / 2);
        for (const slot of neighbours)
            widths[slot] = base - shrink;
        widths[pressedIndex] = base + shrink * neighbours.length;
    }

    return snapToPixels(widths, shown, totalWidth, spacing);
}

/**
 * Round each button's left edge rather than its width.
 *
 * Rounding widths one by one lets the errors accumulate: positions in a row are a running
 * sum, so half a pixel gained on the pressed button and half on each neighbour drags every
 * button to their right off its resting position, and pushes the last one past the end of
 * the row. Rounding the running sum instead keeps a button's edge wherever the exact
 * arithmetic put it, which for anything outside the pressed trio is exactly where it was.
 */
function snapToPixels(widths, shown, totalWidth, spacing) {
    const snapped = widths.map(() => 0);
    let edge = 0;
    let lastSlot = -1;
    let lastEdge = 0;

    for (const slot of shown) {
        const rounded = Math.round(edge);
        if (lastSlot >= 0)
            snapped[lastSlot] = rounded - spacing - lastEdge;
        lastSlot = slot;
        lastEdge = rounded;
        edge += widths[slot] + spacing;
    }
    snapped[lastSlot] = totalWidth - lastEdge;

    return snapped;
}
