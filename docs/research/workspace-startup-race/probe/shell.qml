//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Headless probe: no windows, no surfaces. Dumps the Hyprland singleton's model
// state from the first QML frame onwards so a cold start can be inspected after
// the fact. Referencing `Hyprland` at all is what constructs the C++ singleton,
// so construction happens here at the same point in the lifecycle the real shell
// would trigger it.
ShellRoot {
    id: root

    readonly property double t0: Date.now()
    property string last: ""

    function snapshot() {
        const ws = Hyprland.workspaces?.values ?? [];
        const ids = ws.map(w => w.id).sort((a, b) => a - b);
        const mons = Hyprland.monitors?.values ?? [];
        const monNames = mons.map(m => m.name + ":" + (m.activeWorkspace?.id ?? "-"));

        // The exact expression WorkspaceIndicator.qml:49-61 renders from, so the
        // log shows what the widget would have drawn, not just what the model holds.
        let maxWorkspaceId;
        if (ws.length > 0) {
            const wsIds = ws.map(w => w.id);
            maxWorkspaceId = Math.max(5, Math.max(...wsIds));
            if (Hyprland.focusedWorkspace)
                maxWorkspaceId = Math.max(maxWorkspaceId, Hyprland.focusedWorkspace.id);
        } else {
            maxWorkspaceId = Math.max(5, Hyprland.focusedWorkspace?.id || 0);
        }

        return `ws=[${ids}] mons=[${monNames}]`
            + ` focusedMon=${Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "NULL"}`
            + ` focusedWs=${Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : "NULL"}`
            + ` monActiveWs=${Hyprland.focusedMonitor?.activeWorkspace?.id ?? "NULL"}`
            + ` sock=${Hyprland.requestSocketPath === "" ? "EMPTY" : "ok"}`
            + ` usingLua=${Hyprland.usingLua}`
            + ` widgetDots=${maxWorkspaceId}`;
    }

    function emit(tag) {
        console.log(`PROBE +${Date.now() - t0}ms ${tag} ${snapshot()}`);
    }

    Component.onCompleted: emit("load")

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            const now = root.snapshot();
            if (now !== root.last) {
                root.last = now;
                root.emit("change");
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.emit("heartbeat")
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            console.log(`PROBE +${Date.now() - root.t0}ms event ${event.name} :: ${event.data}`);
        }
    }

    Timer {
        interval: parseInt(Quickshell.env("PROBE_LIFETIME") ?? "20000") || 20000
        running: true
        onTriggered: {
            root.emit("final");
            Qt.quit();
        }
    }
}
