import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 10

    Item {
        width: 50
        height: 20

        Text {
            id: volumnText
            anchors.centerIn: parent
            text: {
                if (Pipewire.ready && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                    const vol = Math.round(Pipewire.defaultAudioSink.audio.volume * 100);
                    return `   ${vol}%`;
                } else {
                    return "";
                }
            }
            color: "white"
            font.pixelSize: 12
        }

        // bind pipewire objects to ensure propertyes are available
        PwObjectTracker {
            objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
        }
    }

    Item {
        width: 60
        height: 20

        Text {
            id: batteryText
            anchors.centerIn: parent
            text: {
                if (UPower.onBattery && UPower.displayDevice.ready) {
                    const percent = Math.round(UPower.displayDevice.percentage);
                    return `󰁹 ${percent}%`;
                } else if (UPower.onBattery) {
                    return "󰁹 ...";
                } else {
                    return " AC";
                }
            }
            color: UPower.onBattery && UPower.displayDevice.ready && UPower.displayDevice.percentage < 20 ? "red" : "white"
            font.pixelSize: 12
        }
    }
}
