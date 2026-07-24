import Quickshell
import QtQuick
import qs.services

ShellRoot {
    property var brightness: Brightness

    Timer {
        id: waitForBrightness

        property int attempts

        interval: 50
        repeat: true
        running: true
        onTriggered: {
            attempts++;
            const monitor = Brightness.getMonitorForScreen(Quickshell.screens[0]);
            if (monitor?.ready) {
                monitor.setBrightness(0.6);
                console.log("BRIGHTNESS_READY");
                stop();
                finish.start();
            } else if (attempts === 40) {
                Qt.quit();
            }
        }
    }

    Timer {
        id: finish

        interval: 200
        onTriggered: Qt.quit()
    }
}
