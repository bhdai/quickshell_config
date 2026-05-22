pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    property bool isActive: false

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
        command: ["bash", "-c", "hyprctl getoption decoration:blur:enabled 2>/dev/null | awk 'NR==1{print $2}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const val = text.trim();
                if (val === "0") {
                    service.isActive = true;
                } else if (val === "1") {
                    service.isActive = false;
                } else {
                    // hyprctl not ready yet or unexpected output.
                    // Default to off and retry shortly.
                    service.isActive = false;
                    retryTimer.start();
                }
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
