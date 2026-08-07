/**
 * The workspace indicator's counting, filtering and geometry, as plain data in and plain
 * data out. WorkspaceIndicator.qml marshals live Hyprland objects into the shapes below;
 * nothing here ever sees one, which is what makes the row's behaviour assertable without a
 * running compositor.
 *
 * Every position in the row is arithmetic from a constant stride. Nothing here reads a
 * rendered position, and the caller must not either: that is the whole fix for a pill that
 * used to park itself wherever the layout happened to be when a binding last evaluated.
 */

.pragma library

// The floor is a resting size for a fresh session. The ceiling is where the keybinds stop
// — SUPER+1..9 and SUPER+0 — rather than where an id you reached by accident does.
const MIN_SLOTS = 5;
const MAX_SLOTS = 10;

/**
 * The row, for one bar.
 *
 * `workspaces` is every workspace Hyprland knows about, unfiltered, as
 * `[{ id, name, windowCount, urgent }]`. `activeId` is the workspace active on *this bar's*
 * monitor, 0 when it cannot be resolved. `specialName` is the special currently visible on
 * this monitor, "" when none is — event-sourced by the caller, never inferred from
 * `workspaces`, because a special sits in that list whenever it holds windows whether or not
 * it is showing.
 *
 * Answers `{ slots: [{ id, occupied, urgent }], activeIndex, special: { name, visible } }`.
 * Slot ids run 1..n contiguously; a slot with no workspace behind it is the normal case.
 * `activeIndex` is -1 whenever there is nowhere to point — no workspaces, an active
 * workspace that is not in the list, or an active id past the ceiling — which is the single
 * condition the caller hides the pill on. The input array is not mutated.
 */
function workspaceModel(state) {
    const activeId = state.activeId;

    // A visible special sorts ahead of workspace 1 in Hyprland's list and carries a negative
    // id, so the filter is load-bearing rather than defensive.
    const ordinals = state.workspaces.filter(workspace => workspace.id >= 1);

    const highest = ordinals.reduce((max, workspace) => Math.max(max, workspace.id), 0);
    const count = Math.min(MAX_SLOTS, Math.max(MIN_SLOTS, highest, activeId));

    const slots = [];
    for (let id = 1; id <= count; ++id) {
        const workspace = ordinals.find(candidate => candidate.id === id);
        slots.push({
            id: id,
            occupied: !!workspace && workspace.windowCount > 0,
            urgent: !!workspace && !!workspace.urgent
        });
    }

    const active = activeId >= 1 && activeId <= count && ordinals.some(workspace => workspace.id === activeId);

    return {
        slots: slots,
        activeIndex: active ? activeId - 1 : -1,
        special: { name: state.specialName, visible: state.specialName !== "" }
    };
}

/**
 * Where the active pill sits and how wide the whole widget is, in pixels.
 *
 * `padding` is measured from the widget's **outer** edge to the first slot's left edge, so
 * `contentWidth` covers the entire item and there is no addend anywhere for the widget's
 * reported bounds and its visible bounds to disagree about. `contentWidth` derives from the
 * slot count alone, so nothing drawn over the row — the special overlay included — can feed
 * it. An `activeIndex` of -1 parks the pill at 0; the caller hides it rather than moving it.
 */
function pillGeometry(row, tokens) {
    const stride = tokens.dotWidth + tokens.spacing;
    const contentWidth = 2 * tokens.padding + row.count * tokens.dotWidth + (row.count - 1) * tokens.spacing;

    if (row.activeIndex < 0)
        return { pillX: 0, contentWidth: contentWidth };

    const slotCentre = tokens.padding + row.activeIndex * stride + tokens.dotWidth / 2;
    return { pillX: slotCentre - tokens.pillWidth / 2, contentWidth: contentWidth };
}

// Hyprland here runs in Lua config mode, where the `hyprctl dispatch workspace 3` form
// errors outright.
function focusCommand(id) {
    return `hl.dsp.focus({ workspace = ${id} })`;
}

/**
 * The payload of Hyprland's `activespecial` event, as `{ name, monitor }`.
 *
 * The event fires on both edges and always names the monitor: `"special:quake,eDP-1"` when
 * one is raised, `",eDP-1"` when the raised one is dismissed. That is what makes special
 * visibility per-monitor and event-sourced rather than something to poll for, and an empty
 * `name` is the *only* thing that clears it — a special sits in `Hyprland.workspaces`
 * whenever it holds windows, and lingers there for a moment after being hidden.
 *
 * The monitor is the last comma-separated field, not the second: a workspace name may
 * contain a comma and a monitor name may not. An absent monitor field yields `""`, which
 * must not be treated as a match for a screen whose own name failed to resolve.
 */
function parseActiveSpecial(data) {
    const text = data ?? "";
    const split = text.lastIndexOf(",");

    if (split === -1)
        return { name: text, monitor: "" };

    return { name: text.slice(0, split), monitor: text.slice(split + 1) };
}
