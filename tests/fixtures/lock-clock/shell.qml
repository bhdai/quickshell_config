import Quickshell
import QtQuick
import qs.modules.lock

/**
 * Builds the clock offscreen and walks it through four times, on a wide output and then on a
 * narrow one. There is no display to check a display-sized clock on, and what matters about
 * it is measurable rather than visual: that it is sized from the output it is composed on
 * with the tracking and leading applied, and that the string keeps its width as the digits
 * change.
 *
 * The clock sits in a window because a positioner only lays its children out on a polish
 * pass, and nothing polishes an item no window owns.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 1920
        implicitHeight: 1080
        visible: true

        LockClock {
            id: clock

            availableWidth: 1920
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                // Assigning to the time's text drops its binding to the clock service, which
                // is what the walk needs: four different minutes out of a half-second run.
                const time = clock.children[0];
                const date = clock.children[1];

                for (const width of [1920, 1280]) {
                    clock.availableWidth = width;
                    const widths = ["11:11", "08:48", "23:59", "10:00"].map(sample => {
                        time.text = sample;
                        return Math.round(time.width * 100);
                    });

                    console.log(`LOCK_CLOCK output=${width} size=${time.font.pixelSize} tracking=${Math.round(time.font.letterSpacing)} leading=${time.lineHeight} gap=${clock.spacing} date=${date.font.pixelSize} render=${time.renderType} widths=${widths.join(",")}`);
                }

                Qt.quit();
            }
        }
    }
}
