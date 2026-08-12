.pragma library

/**
 * Where a tooltip lands, given the anchor it describes and the screen it has to stay on.
 *
 * All rectangles are `{ x, y, width, height }` in the same coordinate space — screen
 * coordinates at every call site, since a tooltip may be its own Wayland surface and cannot
 * reason in the anchor window's local space. `preferred` is "above" or "below"; `gap` is the
 * distance between the anchor's edge and the tooltip's.
 *
 * Returns `{ x, y, side }`, where `side` reports which side was actually used — the caller
 * needs it because a tooltip that flipped has to restart its enter animation from the new
 * side rather than appear to slide across the anchor.
 *
 * Collision handling follows Material 3's implementation rather than a mirror-flip:
 * horizontal overflow shifts the tooltip along the anchor, and only vertical overflow flips
 * it to the other side. A mirror-flip on the horizontal axis would walk the tooltip out from
 * under the thing it is describing.
 */
function place(anchor, size, screen, preferred, gap) {
    const vertical = resolveVertical(anchor, size, screen, preferred, gap);
    return {
        x: resolveHorizontal(anchor, size, screen),
        y: vertical.y,
        side: vertical.side
    };
}

/**
 * Centre on the anchor; on overflow, align to the anchor's near edge instead.
 *
 * The anchor-edge fallbacks are what keep a tooltip pointing at its anchor: sliding it just
 * far enough to fit would leave a short label centred on the screen edge rather than on the
 * icon it belongs to. For any anchor that is itself on screen those fallbacks already land on
 * screen, so the final clamp is not what handles edge anchors — it only catches what
 * alignment cannot, namely a tooltip wider than the screen or an anchor hanging off it.
 */
function resolveHorizontal(anchor, size, screen) {
    const left = screen.x;
    const right = screen.x + screen.width;
    const centred = anchor.x + (anchor.width - size.width) / 2;

    let x = centred;
    if (centred < left)
        x = anchor.x;
    else if (centred + size.width > right)
        x = anchor.x + anchor.width - size.width;

    return Math.max(left, Math.min(x, right - size.width));
}

/**
 * Use the preferred side when it fits, the other side when it does not, and the preferred
 * side anyway when neither fits — a tooltip with nowhere to go is better half off the edge it
 * was asked for than half off the opposite one.
 */
function resolveVertical(anchor, size, screen, preferred, gap) {
    const above = anchor.y - gap - size.height;
    const below = anchor.y + anchor.height + gap;
    const fitsAbove = above >= screen.y;
    const fitsBelow = below + size.height <= screen.y + screen.height;

    if (preferred === "above")
        return (fitsAbove || !fitsBelow) ? { y: above, side: "above" } : { y: below, side: "below" };
    return (fitsBelow || !fitsAbove) ? { y: below, side: "below" } : { y: above, side: "above" };
}
