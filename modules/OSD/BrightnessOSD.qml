import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common.widgets
import qs.modules.common

PanelWindow {
    id: brightnessOsdPanel

    property bool userInteracting: false

    implicitWidth: 400
    implicitHeight: 60

    color: "transparent"
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd:brightness"

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
            if (!brightnessOsdPanel.userInteracting) {
                brightnessOsdPanel.visible = false;
            }
        }
    }

    // Monitor brightness changes
    Connections {
        target: Brightness
        function onBrightnessChanged() {
            brightnessOsdPanel.visible = true;
            hideTimer.restart();
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
                id: brightnessSlider
                anchors.fill: parent
                anchors.margins: 6

                configuration: StyledSlider.Configuration.L

                highlightColor: Colors.accent
                trackColor: Colors.surfaceContainerHighest
                handleColor: Colors.accent
                dotColor: Colors.surfaceContainerHighest
                dotColorHighlighted: Colors.surfaceContainerHighest
                handleMargins: 6

                insetIconSource: "display-brightness-symbolic"
                insetIconColorActive: Colors.background
                insetIconColorInactive: Colors.text
                enableInsetIcon: true

                from: 0.0
                to: 1.0

                property var focusedMonitor: {
                    const focusedName = Hyprland.focusedMonitor.name;
                    const focusedScreen = Quickshell.screens.find(s => s.name === focusedName);
                    return Brightness.getMonitorForScreen(focusedScreen);
                }

                value: focusedMonitor?.brightness ?? 0.0

                onPressedChanged: {
                    brightnessOsdPanel.userInteracting = pressed;
                    if (pressed) {
                        hideTimer.stop();
                    } else {
                        hideTimer.restart();
                    }
                }

                onValueChanged: {
                    if (pressed && focusedMonitor) {
                        focusedMonitor.setBrightness(value);
                    }
                }
            }
        }
    }
}
