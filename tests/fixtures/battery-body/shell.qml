import Quickshell
import QtQuick
import qs.modules.common.widgets

/**
 * Builds the battery body in each power state and reports the glyph and fill it chose and the
 * width it took, which is the part `tests/battery-glyph.test.mjs` cannot reach: that the rule
 * is wired to the drawing, that the fill resolves to real palette colours, and that a body
 * whose glyph overhangs still measures as the body alone.
 *
 * States are set as literals rather than read off Battery, so the run does not depend on what
 * the machine's own battery happens to be doing.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 400
        implicitHeight: 200
        visible: true

        Repeater {
            id: bodies

            model: [
                { name: "discharging", isCharging: false, isPluggedIn: false, percentage: 0.42 },
                { name: "charging", isCharging: true, isPluggedIn: true, percentage: 0.42 },
                { name: "held", isCharging: false, isPluggedIn: true, percentage: 0.69 },
                { name: "full", isCharging: false, isPluggedIn: true, percentage: 1 }
            ]

            BatteryBody {
                required property var modelData

                percentage: modelData.percentage
                isCharging: modelData.isCharging
                isPluggedIn: modelData.isPluggedIn
                isCritical: false
                foreground: "white"
            }
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                for (let i = 0; i < bodies.count; ++i) {
                    const body = bodies.itemAt(i);
                    console.log(`BATTERY_BODY name=${body.modelData.name} glyph=${body.glyph} fill=${body.fillColor} width=${Math.round(body.implicitWidth)} height=${Math.round(body.implicitHeight)}`);
                }
                Qt.quit();
            }
        }
    }
}
