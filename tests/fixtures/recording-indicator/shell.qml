import Quickshell
import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.common.widgets

/**
 * Drives the indicator off the real ScreenRecording service and the real state file, which
 * the harness seeds with a filename stamped a known interval ago. What that reaches, and a
 * stub could not: that the service's FileView actually notices the recorder's file appear
 * and disappear, and that the clock counts from the name rather than from whenever this
 * shell happened to start.
 *
 * The glyph is measured alongside, because a missing ligature does not fail to render --
 * it draws the literal string "screen_record" and blows the bar apart.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 300
        implicitHeight: 60
        visible: true

        property int step: 0

        RecordingIndicator {
            id: indicator
            anchors.centerIn: parent
        }

        MaterialSymbol {
            id: glyph
            text: "screen_record"
            iconSize: 15
            fill: 1
            visible: false
        }

        function report(name) {
            console.log(`RECORDING name=${name} width=${Math.round(indicator.implicitWidth)} visible=${indicator.visible} clock=${ScreenRecording.elapsedText} hasClock=${ScreenRecording.hasClock} glyph=${Math.round(glyph.implicitWidth)}`);
        }

        Timer {
            interval: 700
            running: true
            repeat: true

            onTriggered: {
                window.step++;
                if (window.step === 1) {
                    window.report("recording");
                    // Stopping the recorder is the state file going away, nothing else.
                    Quickshell.execDetached(["rm", "-f", ScreenRecording.statePath]);
                } else {
                    window.report("stopped");
                    Qt.quit();
                }
            }
        }
    }
}
