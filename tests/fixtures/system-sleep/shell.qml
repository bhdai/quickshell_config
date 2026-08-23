import QtQuick
import Quickshell
import qs.services

ShellRoot {
    Connections {
        target: SystemSleep

        function onResumed() {
            console.log(`SYSTEM_SLEEP resumed time=${Time.hoursMinutes}`);
            Qt.quit();
        }
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: {
            console.log("SYSTEM_SLEEP timeout");
            Qt.quit();
        }
    }
}
