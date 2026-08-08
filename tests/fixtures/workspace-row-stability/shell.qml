import Quickshell
import QtQuick
import qs.modules.bar

/**
 * Builds the workspace indicator offscreen and asks whether the dot row survives a change to
 * the data behind it, or is torn down and rebuilt.
 *
 * The row is a Repeater over the array `workspaceModel()` returns. Every input to that
 * binding — a window opening, the active workspace moving, a special being raised — makes it
 * return a fresh array, and a Repeater over an array model does not diff. If that rebuilds
 * the delegates, each one restarts at `opacity: 0` and fades back in: the whole row blinks.
 *
 * `specialName` is the trigger here only because it is the one model input reachable without
 * a compositor. It enters the same binding as the window count does, so what it re-evaluates
 * and what that re-evaluation does to the Repeater is identical.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 400
        implicitHeight: 100
        visible: true

        WorkspaceIndicator {
            id: indicator

            // Held off the origin: the offscreen platform parks a synthetic cursor at 0,0,
            // and a widget under it reads as permanently hovered.
            x: 200
            y: 40
            screen: window.screen
        }

        // The row is the indicator's first visual child, the slots are the children of it
        // that are one dot wide. The pill is wider and the Repeater has no width. The
        // delegates past the row's end are built and kept, so shown-ness is what counts.
        function slots(): var {
            const row = indicator.children[0];
            const found = [];
            for (let i = 0; i < row.children.length; ++i) {
                const child = row.children[i];
                if (child.width === indicator.dotWidth && child.visible)
                    found.push(child);
            }
            return found;
        }

        Timer {
            interval: 400
            running: true
            onTriggered: {
                const settled = window.slots();
                // Stamps identity onto the objects themselves. A rebuilt delegate is a new
                // QObject with an empty objectName, which is unambiguous in a way that
                // comparing JS references to possibly-destroyed objects is not.
                for (let i = 0; i < settled.length; ++i)
                    settled[i].objectName = `slot-${i}`;

                console.log(`SETTLED ${settled.length}`);
                console.log(`SETTLED_OPACITY ${settled.map(slot => slot.opacity).join(",")}`);

                indicator.specialName = "special:probe";
                sampled.start();
            }
        }

        // Short on purpose: the delegate fade is a 200 ms animation, so a sample taken well
        // inside it is what distinguishes a row that was rebuilt from one that was not.
        Timer {
            id: sampled

            interval: 60
            onTriggered: {
                const now = window.slots();
                const survivors = now.filter(slot => slot.objectName !== "").length;

                console.log(`AFTER ${now.length}`);
                console.log(`SURVIVORS ${survivors}`);
                // Proves the binding actually re-ran, so a green result is delegate reuse
                // rather than a model change that never reached the row.
                console.log(`MODEL_SPECIAL ${indicator.workspaceRow.special.name}`);
                console.log(`AFTER_OPACITY ${now.map(slot => slot.opacity.toFixed(3)).join(",")}`);
                Qt.quit();
            }
        }
    }
}
