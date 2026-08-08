import Quickshell
import QtQuick
import qs.modules.bar

/**
 * The real indicator, offscreen, against whatever Hyprland is running.
 *
 * Nothing is drawn on any screen and nothing is dispatched from here: the harness opens a
 * window on an empty workspace from outside, and this reports what that did to the row. The
 * question is whether the slots that were already there survive the row growing — a Repeater
 * over an array model rebuilds all of them when the array's length changes, and a rebuilt
 * slot restarts its entry fade, which is the whole row blinking.
 *
 * Sampling rather than measuring once: the fade is 200 ms and a single late reading would
 * miss it entirely.
 */
ShellRoot {
    id: root

    WorkspaceIndicator {
        id: indicator

        // Held off the origin: the offscreen platform parks a synthetic cursor at 0,0, and a
        // widget under it reads as permanently hovered.
        x: 200
        y: 40
        screen: Quickshell.screens[0]
    }

    // Slots past the row's end are built and kept, so shown-ness is what counts. The pill is
    // wider than a dot and the Repeater itself has no width.
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

    property int stampedCount: 0
    property string last: ""

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            const settled = root.slots();
            // Stamps identity onto the objects themselves. A rebuilt delegate is a new
            // QObject with an empty objectName, which is unambiguous in a way that comparing
            // JS references to possibly-destroyed objects is not.
            for (let i = 0; i < settled.length; ++i)
                settled[i].objectName = `stamped-${i}`;

            root.stampedCount = settled.length;
            console.log(`STAMPED ${settled.length}`);
            sampler.start();
        }
    }

    Timer {
        id: sampler

        interval: 16
        repeat: true
        onTriggered: {
            const now = root.slots();
            const survivors = now.filter(slot => slot.objectName !== "");
            const faded = survivors.filter(slot => slot.opacity < 0.999).length;
            const line = `count=${now.length} survivors=${survivors.length} faded=${faded}`;

            if (line !== root.last) {
                root.last = line;
                console.log(`SAMPLE ${line}`);
            }
        }
    }
}
