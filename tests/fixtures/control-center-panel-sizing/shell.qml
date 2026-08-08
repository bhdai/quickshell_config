import Quickshell
import QtQuick
import qs.modules.controlCenter

/**
 * Builds the control center's content and measures it as the showing panel changes.
 *
 * Two things are being held to to here. The bottom container is the height of whichever panel
 * is in it, rather than the height the window has left over — under the old rule every panel
 * was handed that leftover, so all of them looked correct whatever they had asked for. And
 * only that container's bottom edge may move: the card above it holds its size and position,
 * so the gap between the two is the same in every state.
 *
 * The content rather than ControlCenter.qml, because ControlCenter raises a layer surface and
 * this needs to measure the items, not the window.
 *
 * The panels read live services — a scan finds access points, BlueZ reports devices, the
 * notification list is whatever the session is holding. None of that is fixed, and it arrives
 * asynchronously, so every case here waits for the panel to stop changing height before it
 * compares. What is asserted is the relationship between the numbers, never the numbers.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 430
        implicitHeight: 900
        visible: true

        // Sized explicitly rather than anchored to the window, and to exactly what
        // ControlCenter.qml gives it: 430x900 less its 10px margins. A compositor is free to
        // resize a FloatingWindow, and anchoring to one measures whatever size it chose — which
        // hides the case where the content is a few pixels short of what it asked for.
        ControlCenterContent {
            id: content

            width: 410
            height: 880
            availableHeight: height
        }

        // The panel's own asking height beside what the container gave it, and the geometry
        // that has to hold still: where the card sits and how tall it is, and where the
        // container's top edge lands. Only the container's height may differ between states.
        function measure(label: string): void {
            const loader = content.bottomWindow;
            const panel = loader.item;
            console.log(`CC ${label} cardy=${Math.round(content.topWindow.y)}` + ` card=${Math.round(content.topWindow.height)} top=${Math.round(loader.y)}` + ` slot=${Math.round(loader.height)} asked=${Math.round(panel?.implicitHeight ?? -1)}` + ` max=${Math.round(content.maxPanelHeight)}` + ` notifications=${content.notificationCount}`);
        }

        // Opening is not a resize. The container reads its height off a Loader with no item on
        // the first pass, so the real height arrives as a jump from zero — animating that
        // unrolls the panel from nothing every time the control center appears. Measured on the
        // very first frame, which is the only place an opening animation is visible.
        FrameAnimation {
            running: true

            onTriggered: {
                const loader = content.bottomWindow;
                console.log(`OPEN got=${Math.round(loader.height)}` + ` asked=${Math.round(loader.item?.implicitHeight ?? -1)}`);
                running = false;
            }
        }

        // The asking height has to stop moving before the container can be held to it: a
        // service that answers late changes what the panel wants, and the container is a
        // 200ms animation behind it by design.
        property real lastAsked: -1
        property int settled: 0

        function settledNow(): bool {
            const asked = content.bottomWindow.item?.implicitHeight ?? -1;
            settled = asked === lastAsked ? settled + 1 : 0;
            lastAsked = asked;
            return settled >= 2;
        }

        // The notification list twice, once on the way in and once on the way back, so a panel
        // that fails to give its height back is caught as well as one that fails to take it.
        readonly property var cases: [
            {
                label: "notifications",
                panel: ""
            },
            {
                label: "wifi",
                panel: "wifi"
            },
            {
                label: "bluetooth",
                panel: "bluetooth"
            },
            {
                label: "closed",
                panel: ""
            }
        ]
        property int index: 0
        property int ticks: 0

        Timer {
            interval: 250
            running: true
            repeat: true

            onTriggered: {
                // The whole run is under a timeout, but hitting it reports as a shell that
                // never loaded. A panel whose height never settles says so itself.
                if (++window.ticks > 80) {
                    console.log(`CC stuck at=${window.cases[window.index].label} asked=${window.lastAsked}`);
                    Qt.quit();
                    return;
                }

                if (!window.settledNow())
                    return;

                window.measure(window.cases[window.index].label);

                if (++window.index >= window.cases.length) {
                    Qt.quit();
                    return;
                }

                content.openPanel = window.cases[window.index].panel;
                window.settled = 0;
                window.lastAsked = -1;
            }
        }
    }
}
