pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "audio_nodes.js" as AudioNodes

Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource

    // Port availability lives in PulseAudio's view of a sink, not on the PipeWire node, so it
    // is read through pactl. Read once at startup so the first open of a picker is already
    // filtered; the picker refreshes it while it is open, since plugging in a cable changes a
    // port and nothing in the node list.
    property var sinkAvailability: ({})
    readonly property var outputs: AudioNodes.listedOutputs(Pipewire.nodes.values, root.sinkAvailability, root.sink)
    readonly property var appStreams: Pipewire.nodes.values.filter(node => AudioNodes.isAppStream(node))

    // The node getters below read volume and properties, which PipeWire only fills in for a node
    // something tracks: callers hold a PwObjectTracker over the nodes they show.
    function setOutput(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function refreshOutputAvailability(): void {
        if (!availabilityProc.running)
            availabilityProc.running = true;
    }

    // Resolves a row from AudioNodes.nodeRows back to its live node, or null once it is gone.
    function nodeFor(id: int, name: string): PwNode {
        return Pipewire.nodes.values.find(node => node.id === id && node.name === name) ?? null;
    }

    function nodeProperties(node: PwNode): var {
        return node?.ready && node.properties ? node.properties : {};
    }

    function outputLabel(node: PwNode): string {
        return AudioNodes.outputLabel(node);
    }

    function outputSymbol(node: PwNode): string {
        return AudioNodes.outputSymbol(node, root.nodeProperties(node)["device.icon-name"] ?? "");
    }

    function streamLabel(node: PwNode): string {
        return AudioNodes.streamLabel(root.nodeProperties(node), node);
    }

    function streamIconName(node: PwNode): string {
        return AudioNodes.streamIconName(root.nodeProperties(node));
    }

    function nodeRows(nodes: var): var {
        return AudioNodes.nodeRows(nodes);
    }

    Process {
        id: availabilityProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: root.sinkAvailability = AudioNodes.parseSinkAvailability(text)
        }
    }
    
    // Cached volume that gets updated properly
    property real sinkVolume: 0
    
    // Helper to get current volume, filtering NaN
    function getCurrentVolume(): real {
        const vol = sink?.audio?.volume ?? 0;
        return isNaN(vol) ? 0 : vol;
    }
    
    property string symbol: ready && sink?.audio ? (sink.audio.muted ? "audio-volume-muted-symbolic" : (sinkVolume > 0.7 ? "audio-volume-high-symbolic" : sinkVolume > 0.3 ? "audio-volume-medium-symbolic" : sinkVolume > 0.0 ? "audio-volume-low-symbolic" : "audio-volume-muted-symbolic")) : "audio-volume-muted-symbolic"
    readonly property bool sinkProtectionEnabled: false
    readonly property real hardMaxValue: 2.00 // Absolute maximum volume (200%) - prevents extreme over-amplification

    onReadyChanged: {
        if (ready) {
            volumeRecoveryTimer.restart()
        }
    }
    onSinkChanged: volumeRecoveryTimer.restart()
    Component.onCompleted: {
        sinkVolume = getCurrentVolume();
        refreshOutputAvailability();
    }
    
    // Timer to recover from NaN volume state (poll for up to 5 seconds)
    Timer {
        id: volumeRecoveryTimer
        interval: 100
        repeat: true
        property int attempts: 0
        onTriggered: {
            const vol = root.getCurrentVolume()
            if (vol > 0 || attempts >= 50) {
                root.sinkVolume = vol
                stop()
                attempts = 0
            } else {
                attempts++
            }
        }
    }

    signal sinkProtectionTriggered(string reason)

    PwObjectTracker {
        objects: [sink, source]
    }

    Connections {
        target: sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            // Guard against null audio object
            if (!sink?.audio) {
                lastReady = false;
                lastVolume = 0;
                return;
            }

            const newVolume = sink.audio.volume;

            // NaN/undefined check runs FIRST, regardless of protection setting
            if (isNaN(newVolume) || newVolume === undefined || newVolume === null) {
                lastReady = false;
                lastVolume = 0;
                // Start recovery timer when we get NaN
                volumeRecoveryTimer.restart()
                return;
            }

            // Update the cached sinkVolume
            root.sinkVolume = newVolume;

            // Hard max enforcement - always runs as safety net
            if (newVolume > root.hardMaxValue) {
                sink.audio.volume = root.hardMaxValue;
                root.sinkProtectionTriggered("Exceeded hard max");
                lastVolume = root.hardMaxValue;
                root.sinkVolume = root.hardMaxValue;
                return;
            }

            // Protection system (optional)
            if (!root.sinkProtectionEnabled) {
                lastVolume = newVolume;
                return;
            }

            if (!lastReady) {
                lastVolume = newVolume;
                lastReady = true;
                return;
            }

            const maxAllowedIncrease = 0.1;
            const maxAllowed = 0.99;

            if (newVolume - lastVolume > maxAllowedIncrease) {
                sink.audio.volume = lastVolume;
                root.sinkProtectionTriggered("Illegal increment");
            } else if (newVolume > maxAllowed) {
                root.sinkProtectionTriggered("Exceeded max allowed");
                sink.audio.volume = Math.min(lastVolume, maxAllowed);
            }
            lastVolume = sink.audio.volume;
            root.sinkVolume = sink.audio.volume;
        }
    }
}
