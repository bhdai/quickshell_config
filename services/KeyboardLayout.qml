pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "KeyboardLayoutParse.js" as KeyboardLayoutParse

/**
 * The keyboard layout Hyprland is currently applying, as its xkb code ("us").
 *
 * Neither Qt nor Quickshell.Hyprland 0.3.0 exposes a keyboard model, so the value comes
 * from the compositor's own device query. It is read on demand rather than kept fresh:
 * `refresh()` on a moment the answer is about to be shown, plus the compositor's
 * active-layout event for the moments it changes. There is deliberately no timer — the
 * layout only moves when someone switches it, and that arrives as an event.
 *
 * "" until a query has answered, and "" again if the query fails, so a caller shows
 * nothing rather than a stale or invented layout.
 */
Singleton {
    id: root

    property string layout: ""

    // Setting `running` on a Process that is already running is a no-op, so two mirrored
    // lock surfaces seeding on the same edge cost one query rather than two.
    function refresh(): void {
        devicesProc.running = true;
    }

    Process {
        id: devicesProc

        command: ["hyprctl", "devices", "-j"]
        environment: ({
                LANG: "C",
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: root.layout = KeyboardLayoutParse.activeLayout(text)
        }
    }

    Connections {
        target: Hyprland

        // The event's own payload is the long xkb description ("English (US)"), not the
        // code, so it is used as the trigger for a re-read rather than as the value —
        // otherwise a switched layout would read differently from a seeded one.
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout")
                root.refresh();
        }
    }
}
