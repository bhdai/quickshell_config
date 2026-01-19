pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

/**
 * TrayService - Manages system tray items, splitting into pinned (inline) and unpinned (overflow)
 */
Singleton {
    id: root

    // Hardcoded list of app IDs to pin inline in the bar
    // Edit this list to customize which apps appear inline vs in overflow
    readonly property var pinnedIds: ["fcitx", "librepods"]

    // Items matching pinnedIds - display inline in bar
    readonly property var pinnedItems: SystemTray.items.values.filter(item =>
        pinnedIds.includes(item.id.toLowerCase())
    )

    // Items NOT matching pinnedIds - display in overflow popup
    readonly property var unpinnedItems: SystemTray.items.values.filter(item =>
        !pinnedIds.includes(item.id.toLowerCase())
    )

    // Helper to check if an item is pinned
    function isPinned(itemId: string): bool {
        return pinnedIds.includes(itemId.toLowerCase())
    }
}
