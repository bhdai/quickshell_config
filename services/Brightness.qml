pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtCore
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root

    signal brightnessChanged

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
            screen
        }))

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function increaseBrightness(): void {
        // Null until Hyprland has answered the first monitor query, which can be
        // after the first keypress reaches us.
        const focusedName = Hyprland.focusedMonitor?.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const focusedName = Hyprland.focusedMonitor?.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        if (StandardPaths.findExecutable("ddcutil").toString())
            ddcProc.running = true;
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root.ddcMonitors.push({
                        model: lines.find(l => l.startsWith("Monitor:")).split(":")[2],
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onExited: root.ddcMonitorsChanged()
    }

    Process {
        id: setProc
    }

    // The kernel emits a udev change event for every backlight write, including
    // ones this shell did not make: firmware/ACPI handling of the laptop
    // brightness keys, hypridle, a stray brightnessctl. Without re-reading the
    // device on those events the value cached here is write-only — it drifts out
    // of sync with the panel, and the next relative adjustment steps from the
    // stale value instead of the real one.
    Process {
        id: udevProc

        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("(backlight)"))
                    root.monitors.forEach(m => m.scheduleRefresh());
            }
        }
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property bool isDdc: {
            const match = root.ddcMonitors.find(m => m.model === screen.model && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return !!match;
        }
        readonly property string busNum: {
            const match = root.ddcMonitors.find(m => m.model === screen.model && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return match?.busNum ?? "";
        }
        property int rawMaxBrightness: 100
        property real brightness
        property bool ready: false

        onBrightnessChanged: {
            if (monitor.ready) {
                root.brightnessChanged();
            }
        }

        function initialize() {
            monitor.ready = false;
            initProc.command = isDdc ? ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"] : ["sh", "-c", `echo "a b c $(brightnessctl g) $(brightnessctl m)"`];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const [, , , current, max] = data.split(" ");
                    monitor.rawMaxBrightness = parseInt(max);
                    monitor.brightness = parseInt(current) / monitor.rawMaxBrightness;
                    monitor.ready = true;
                }
            }
        }

        // We need a delay for DDC monitors because they can be quite slow and might act weird with rapid changes
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 0
            onTriggered: {
                syncBrightness();
            }
        }

        // Coalesce bursts of events — key repeat, a slider drag — into one read
        // after they settle, so a read can never overtake a write we just issued
        // and snap the value back to what the device held a moment ago.
        property var refreshTimer: Timer {
            id: refreshTimer
            interval: 200
            onTriggered: monitor.initProc.running = true
        }

        // DDC monitors have no backlight device behind these events; they are
        // driven over I2C and report through ddcutil instead.
        function scheduleRefresh(): void {
            if (!monitor.isDdc && monitor.ready)
                refreshTimer.restart();
        }

        function syncBrightness() {
            const rounded = Math.round(monitor.brightness * monitor.rawMaxBrightness);
            setProc.command = isDdc ? ["ddcutil", "-b", busNum, "setvcp", "10", rounded] : ["brightnessctl", "--class", "backlight", "s", rounded, "--quiet"];
            setProc.startDetached();
        }

        function setBrightness(value: real): void {
            value = Math.max(0.01, Math.min(1, value));
            monitor.brightness = value;
            setTimer.restart();
        }

        Component.onCompleted: {
            initialize();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    IpcHandler {
        target: "brightness"

        function increment() {
            onPressed: root.increaseBrightness();
        }

        function decrement() {
            onPressed: root.decreaseBrightness();
        }
    }
}
