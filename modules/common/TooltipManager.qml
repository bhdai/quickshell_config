pragma Singleton

import QtQuick
import Quickshell

/**
 * The single owner of "which tooltip is showing".
 *
 * Material 3 requires that triggering a tooltip closes any other one. Nothing else in this
 * shell can enforce that: a tooltip anchored to a bar item is its own Wayland surface, so two
 * tooltips have no common parent to arbitrate between them.
 *
 * A tooltip calls `claim` when it wants to show and `release` when it stops. `claim` returns
 * whether the caller should play its enter animation.
 */
Singleton {
    id: root

    property var current: null

    /**
     * Take over as the visible tooltip, dismissing whichever one was showing.
     *
     * Returns false when another tooltip was visible in the last few hundred milliseconds,
     * meaning the caller should appear without its enter animation. Dragging the pointer
     * along a row of bar icons otherwise starts a fresh scale-and-fade per icon, none of
     * which finishes; suppressing it makes the sweep read as one chip moving between anchors.
     */
    function claim(tooltip) {
        if (root.current === tooltip)
            return !handover.running;

        const previous = root.current;
        root.current = tooltip;
        if (previous !== null) {
            previous.dismiss();
            handover.restart();
        }
        return !handover.running;
    }

    function release(tooltip) {
        // A tooltip displaced by `claim` is no longer current by the time it releases, and
        // must not clear the incoming one.
        if (root.current !== tooltip)
            return;
        root.current = null;
        handover.restart();
    }

    Timer {
        id: handover
        interval: 250
    }
}
