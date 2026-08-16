pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "screen_recording.js" as ScreenRecording

// The screen recorder's state, taken from the one file
// config/hypr/scripts/capture-screenrecording keeps for exactly the lifetime of a
// recording -- so this watches a file rather than polling for gpu-screen-recorder. The
// contents are the path being written, which is also where the start time is read from.
Singleton {
    id: root

    readonly property string statePath: `${Quickshell.env("XDG_RUNTIME_DIR")}/screenrecording-filename`

    // The file being written, or empty when nothing is recording.
    property string path: ""
    readonly property bool active: root.path !== ""

    // Epoch milliseconds, or 0 when the path carries no timestamp to read.
    readonly property real startedAt: {
        const parsed = ScreenRecording.parseStartTime(root.path);
        return parsed === null ? 0 : parsed;
    }
    readonly property bool hasClock: root.startedAt > 0

    property real now: 0
    readonly property int elapsed: root.hasClock ? Math.max(0, Math.floor((root.now - root.startedAt) / 1000)) : 0
    readonly property string elapsedText: ScreenRecording.formatElapsed(root.elapsed)

    FileView {
        path: root.statePath
        watchChanges: true
        // Absent for the whole of any session that records nothing, which is most of them.
        printErrors: false

        onLoaded: {
            root.path = text().trim();
            // Without this the clock would read 0:00 until the tick below first fires, so a
            // recording the shell was restarted underneath would appear to start over.
            root.now = Date.now();
        }
        onLoadFailed: root.path = ""
        onFileChanged: reload()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.now = Date.now()
    }
}
