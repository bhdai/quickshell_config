pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource
    property string symbol: ready && sink?.audio ? (sink.audio.muted ? "audio-volume-muted-symbolic" : (sink.audio.volume > 0.7 ? "audio-volume-high-symbolic" : sink.audio.volume > 0.3 ? "audio-volume-medium-symbolic" : sink.audio.volume > 0.0 ? "audio-volume-low-symbolic" : "audio-volume-muted-symbolic")) : "audio-volume-muted-symbolic"
    readonly property bool sinkProtectionEnabled: false
    readonly property real hardMaxValue: 2.00 // Absolute maximum volume (200%) - prevents extreme over-amplification

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
                return;
            }

            // Hard max enforcement - always runs as safety net
            if (newVolume > root.hardMaxValue) {
                sink.audio.volume = root.hardMaxValue;
                root.sinkProtectionTriggered("Exceeded hard max");
                lastVolume = root.hardMaxValue;
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
        }
    }
}
