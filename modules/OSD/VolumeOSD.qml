import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common.widgets
import qs.modules.common

PanelWindow {
    id: volumeOsdPanel

    property bool userInteracting: false

    implicitWidth: 400
    implicitHeight: 60

    color: "transparent"
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd:volume"

    exclusiveZone: 0

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        bottom: 80
    }

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!volumeOsdPanel.userInteracting) {
                volumeOsdPanel.visible = false;
            }
        }
    }

    // Monitor audio volume changes
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (Audio.ready) {
                volumeOsdPanel.visible = true;
                hideTimer.restart();
            }
        }
    }

    // Monitor audio mute changes
    Connections {
        target: Audio.sink?.audio ?? null
        function onMutedChanged() {
            if (Audio.ready) {
                volumeOsdPanel.visible = true;
                hideTimer.restart();
            }
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 42
            radius: 21
            color: "transparent"
            // opacity: 0.95

            StyledSlider {
                id: volumeSlider
                anchors.fill: parent
                anchors.margins: 6

                configuration: StyledSlider.Configuration.L

                highlightColor: Colors.accent
                trackColor: Colors.surfaceContainerHighest
                handleColor: Colors.accent
                dotColor: Colors.surfaceContainerHighest
                dotColorHighlighted: Colors.surfaceContainerHighest
                handleMargins: 6

                insetIconSource: Audio.symbol
                insetIconColorActive: Colors.background
                insetIconColorInactive: Colors.text
                enableInsetIcon: true

                from: 0.0
                to: 1.0
                value: Audio.ready ? Audio.sink.audio.volume : 0.0

                onPressedChanged: {
                    volumeOsdPanel.userInteracting = pressed;
                    if (pressed) {
                        hideTimer.stop();
                    } else {
                        hideTimer.restart();
                    }
                }

                onValueChanged: {
                    if (pressed && Audio.ready) {
                        Audio.sink.audio.volume = value;
                    }
                }
            }
        }
    }
}
