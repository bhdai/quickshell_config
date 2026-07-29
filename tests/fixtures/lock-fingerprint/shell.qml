import Quickshell
import QtQuick
import qs.modules.lock

/**
 * Walks the fingerprint affordance through every state, which nothing else reaches: two of
 * them need a reader, and one of those needs a reader that has just refused a finger. A
 * QML error in the rejected treatment would otherwise first surface behind a locked
 * screen, on the one touch that did not work.
 *
 * The affordance reads no singleton, so the state is set here as a plain property — no
 * PAM, no reader, and nothing that could unlock anything.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 600
        implicitHeight: 200
        visible: true

        LockFingerprint {
            id: affordance

            anchors.centerIn: parent
            phase: "armed"
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                for (const phase of ["absent", "armed", "rejected", "a-fourth-state"]) {
                    affordance.phase = phase;

                    const treatment = affordance.treatment;
                    console.log(`LOCK_FINGERPRINT phase=${phase} visible=${treatment.visible} tone=${treatment.tone} shake=${treatment.shake}`);
                }

                // The size is reported separately and a frame later: a positioner's
                // implicit size settles in the layout pass, so reading it inside the walk
                // would report the state before the one just set.
                affordance.phase = "armed";
                settle.start();
            }
        }

        Timer {
            id: settle

            interval: 200
            onTriggered: {
                console.log(`LOCK_FINGERPRINT_LAYOUT width=${Math.round(affordance.implicitWidth)} height=${Math.round(affordance.implicitHeight)}`);
                Qt.quit();
            }
        }
    }
}
