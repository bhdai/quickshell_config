import QtQuick
import Quickshell
import qs.modules.controlCenter.notifications

ShellRoot {
    FloatingWindow {
        implicitWidth: 400
        implicitHeight: 100
        visible: true

        NotificationItem {
            anchors.fill: parent
            compact: true
            showHeader: false
            notif: ({
                appName: "Test application",
                summary: "A deliberately long compact notification summary",
                body: "A deliberately long notification body that consumes the remaining width",
                image: "",
                time: Date.now()
            })
        }
    }

    Timer {
        interval: 200
        running: true
        onTriggered: Qt.quit()
    }
}
