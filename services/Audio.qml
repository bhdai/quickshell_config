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
    Component.onCompleted: sinkVolume = getCurrentVolume()
    
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
