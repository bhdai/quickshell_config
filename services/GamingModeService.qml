pragma Singleton
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
        running: true
        command: ["bash", "-c", `test "$(hyprctl getoption decoration:blur:enabled | awk 'NR==1{print$2}')" -ne 0`]
        onExited: (exitCode, exitStatus) => {
            service.isActive = exitCode !== 0;
        }
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
