import Quickshell
import QtQuick
import qs.services

ShellRoot {
    property var brightness: Brightness

    Timer {
        property int attempts

        interval: 50
        repeat: true
        running: true
        onTriggered: {
            attempts++;
            const monitor = Brightness.getMonitorForScreen(Quickshell.screens[0]);
            if (!monitor?.ready) {
                if (attempts === 100) {
                    console.log("NEVER_READY");
                    Qt.quit();
                }
                return;
            }
            if (Math.abs(monitor.brightness - 0.8) < 0.001) {
                console.log("EXTERNAL_SYNCED");
                Qt.quit();
            } else if (attempts === 100) {
                console.log(`STALE brightness=${monitor.brightness}`);
                Qt.quit();
            }
        }
    }
}
