.pragma library

/**
 * The xkb code of the layout currently in effect on the keyboard Hyprland routes input to,
 * read from `hyprctl devices -j`. Returns "" for anything unusable, so a caller renders
 * nothing rather than a guess — this runs on the lock screen, where a thrown exception
 * would land in a surface the user cannot dismiss.
 *
 * Two fields are needed, not one. `layout` is the *configured* list ("us,de") and is
 * identical on every keyboard the compositor knows about, including the power button and
 * the video bus, so `main` picks the one actually receiving keystrokes and
 * `active_layout_index` picks the entry of the list in effect on it.
 *
 * The event stream's layout name is deliberately not a source here: it carries the long
 * xkb description ("English (US)") rather than the code, so a layout that was switched into
 * would otherwise read differently from one that was seeded.
 */
function activeLayout(devicesJson) {
    let devices;
    try {
        devices = JSON.parse(devicesJson);
    } catch (error) {
        return "";
    }

    const keyboards = devices?.keyboards ?? [];
    const keyboard = keyboards.find(k => k.main) ?? keyboards[0];
    if (!keyboard)
        return "";

    const layouts = String(keyboard.layout ?? "").split(",").map(l => l.trim()).filter(l => l);
    return layouts[keyboard.active_layout_index ?? 0] ?? layouts[0] ?? "";
}
