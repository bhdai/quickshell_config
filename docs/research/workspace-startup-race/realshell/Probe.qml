import Quickshell
import Quickshell.Hyprland
import QtQuick

// Instrumentation only — never committed to the config. Reports the Hyprland
// singleton's model against wall-clock time so a cold start can be inspected after
// the fact. Instantiated last in shell.qml so it observes a singleton the rest of
// the shell has already constructed.
Scope {
    id: root

    readonly property double t0: Date.now()
    property string last: ""

    function snapshot() {
        const ws = Hyprland.workspaces?.values ?? [];
        const ids = ws.map(w => w.id).sort((a, b) => a - b);
        const mons = Hyprland.monitors?.values ?? [];
        const monNames = mons.map(m => m.name + ":" + (m.activeWorkspace?.id ?? "-"));

        // The exact expression WorkspaceIndicator.qml:49-61 renders from, so the log
        // shows what the widget drew, not just what the model held.
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

    // Can a shell repair its own model from QML? refreshWorkspaces() cannot create,
    // but refreshToplevels() has no such gate, and the workspaces parse has a
    // name-based fallback for id -1 entries. Run them in that order and see.
    // Each refresh lands in a later event-loop turn, so the stages are spaced out
    // rather than called back to back.
    property int recoverAt: parseInt(Quickshell.env("PROBE_RECOVER") ?? "9000") || 9000

    Timer {
        interval: root.recoverAt
        running: true
        onTriggered: {
            root.emit("recover:before");
            Hyprland.refreshToplevels();
        }
    }

    Timer {
        interval: root.recoverAt + 500
        running: true
        onTriggered: {
            root.emit("recover:after-toplevels");
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
        }
    }

    Timer {
        interval: root.recoverAt + 1000
        running: true
        onTriggered: root.emit("recover:after-workspaces")
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
