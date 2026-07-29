import Quickshell
import QtQuick
import qs.modules.common
import qs.modules.lock

/**
 * Constructs the power controls and arms one, which is the part no other check reaches: the
 * smoke run loads the shell but never raises a lock, so a QML error in this component would
 * first surface behind a locked screen.
 *
 * Only the arming half is exercised. Confirming would call the session service for real, and
 * a test that reboots the machine running it is not a test.
 *
 * The controls sit in a window because QtQuick.Layouts only recomputes an implicit size on a
 * polish pass, and nothing polishes an item no window owns.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 800
        implicitHeight: 200
        visible: true

        LockPowerControls {
            id: controls
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                controls.press("poweroff");
                const armed = controls.pending;

                // A press on a sibling has to move the confirm rather than fire what was
                // armed — the case a user backing out of shutdown walks straight into.
                controls.press("reboot");

                console.log(`LOCK_POWER_CONTROLS width=${Math.round(controls.implicitWidth)} minWidth=${Math.round(3 * Appearance.sizes.lockPowerButton)} armed=${armed} moved=${controls.pending}`);
                Qt.quit();
            }
        }
    }
}
