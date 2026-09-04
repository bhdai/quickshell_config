pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "GamingModeParse.js" as GamingModeParse

Singleton {
    id: service

    property bool isActive: false

    // The hyprctl eval below turns blur off compositor-wide. Translucent surfaces with nothing
    // blurred behind them are just hard to read, so the shell's transparency has to collapse
    // with it. A Binding rather than assignments in toggle() because isActive is also set by
    // the startup probe and its retry, and all three paths have to move this together.
    Binding {
        target: Appearance
        property: "reducedEffects"
        value: service.isActive
    }

    function toggle(): void {
        service.isActive = !service.isActive;

        if (service.isActive) {
            Quickshell.execDetached(["hyprctl", "eval",
                "hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true } })"
            ]);
        } else {
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    Process {
        id: fetchActiveState
        command: ["hyprctl", "-j", "getoption", "decoration:blur:enabled"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const active = GamingModeParse.activeFromBlurOption(text);
                if (active !== null) {
                    service.isActive = active;
                    return;
                }

                // hyprctl not ready yet or unexpected output.
                // Default to off and retry shortly.
                service.isActive = false;
                retryTimer.start();
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 2000
        onTriggered: fetchActiveState.running = true
    }

    IpcHandler {
        target: "gamingMode"

        function toggle(): void {
            service.toggle();
        }

        function getState(): bool {
            return service.isActive;
        }
    }
}
