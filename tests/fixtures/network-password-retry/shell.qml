import Quickshell
import QtQuick
import qs.services

ShellRoot {
    WifiAccessPoint {
        id: accessPoint
        lastIpcObject: ({
                ssid: "Test Network",
                bssid: "00:11:22:33:44:55",
                strength: 80,
                frequency: 5180,
                active: false,
                security: "WPA2"
            })
    }

    Timer {
        interval: 50
        running: true
        onTriggered: Network.connectToWifiNetwork(accessPoint)
    }

    Timer {
        id: passwordPrompt
        property int attempts

        interval: 10
        repeat: true
        running: true
        onTriggered: {
            attempts++;
            if (accessPoint.askingPassword && !Network.wifiConnecting) {
                stop();
                Network.changePassword(accessPoint, "new-password");
                finish.start();
            } else if (attempts === 100) {
                Qt.quit();
            }
        }
    }

    Timer {
        id: finish
        interval: 200
        onTriggered: {
            console.log("PASSWORD_RETRY_ASKING=" + accessPoint.askingPassword);
            Qt.quit();
        }
    }
}
