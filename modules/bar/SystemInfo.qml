import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
    // spacing: 10

    // Volume indicator
    Item {
        width: 60
        height: 20

        Text {
            id: volumeText
            anchors.centerIn: parent
            text: {
                if (Pipewire.ready && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                    const vol = Math.round(Pipewire.defaultAudioSink.audio.volume * 100);
                    return `󰕾  ${vol}%`;
                } else {
                    return "󰕾 --%";
                }
            }
            color: "white"
            font.pixelSize: 12
        }

        // bind pipewire objects to ensure properties are available
        PwObjectTracker {
            objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
        }
    }

    // WiFi indicator (placeholder)
    Item {
        width: 30
        height: 20

        Text {
            anchors.centerIn: parent
            text: ""
            color: "white"
            font.pixelSize: 12
        }
    }

    // Bluetooth indicator (placeholder)
    Item {
        width: 30
        height: 20

        Text {
            anchors.centerIn: parent
            text: "󰂯"
            color: "white"
            font.pixelSize: 12
        }
    }

    // Battery indicator
    Item {
        width: 70
        height: 20

        Text {
            id: batteryText
            anchors.centerIn: parent
            text: {
                const percent = Math.round(UPower.displayDevice.percentage * 100);
                if (UPower.onBattery) {
                    return `󰁹 ${percent}%`;
                } else {
                    return ` ${percent}%`;
                }
            }
            color: UPower.onBattery && UPower.displayDevice.ready && UPower.displayDevice.percentage * 100 < 20 ? "red" : "white"
            font.pixelSize: 12
        }
    }
}
