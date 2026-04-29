pragma Singleton
import Quickshell
import Quickshell.Io

// Owns the entire warp-cli lifecycle. The UI never touches warp-cli directly.
Singleton {
    id: service

    // Whether WARP is currently connected. UI binds to this.
    property bool isActive: false

    // Public entry point called by the UI onClicked and by IPC.
    //
    // Applies an optimistic update immediately so the UI feels responsive,
    // then delegates to the appropriate process. If the process exits with
    // a non-zero code the update is rolled back and the user is notified.
    function toggle(): void {
        service.isActive = !service.isActive;

        if (service.isActive) {
            connectProc.running = true;
        } else {
            disconnectProc.running = true;
        }
    }

    // Runs `warp-cli connect`. Started on demand by toggle().
    Process {
        id: connectProc
        command: ["warp-cli", "connect"]
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Rollback the optimistic update so the UI reflects reality.
                service.isActive = false;
                Quickshell.execDetached(["notify-send", "WARP Connection Failed", "warp-cli connect exited with error", "-u", "critical", "-a", "Shell"]);
            }
        }
    }

    // Runs `warp-cli disconnect`. Started on demand by toggle().
    Process {
        id: disconnectProc
        command: ["warp-cli", "disconnect"]
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Rollback the optimistic update so the UI reflects reality.
                service.isActive = true;
                Quickshell.execDetached(["notify-send", "WARP Disconnection Failed", "warp-cli disconnect exited with error", "-u", "critical", "-a", "Shell"]);
            }
        }
    }

    // Startup probe — parses `warp-cli status` stdout to determine the initial
    // connection state. Runs automatically once when the service is created.
    Process {
        id: fetchActiveState
        command: ["warp-cli", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("Connected")) {
                    service.isActive = true;
                } else if (text.includes("Disconnected")) {
                    service.isActive = false;
                }
                // Otherwise leave isActive at the default false.
            }
        }
    }

    IpcHandler {
        target: "warp"

        function toggle(): void {
            service.toggle();
        }

        function getState(): bool {
            return service.isActive;
        }
    }
}
