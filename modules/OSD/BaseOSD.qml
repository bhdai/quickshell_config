import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common.widgets
import qs.modules.common

PanelWindow {
    id: baseOsd

    property bool userInteracting: false
    property alias sliderValue: slider.value
    property alias sliderFrom: slider.from
    property alias sliderTo: slider.to
    property alias sliderIcon: slider.insetIconSource

    signal sliderMoved(real value)

    implicitWidth: 400
    implicitHeight: 150

    color: "transparent"
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Overlay

    exclusiveZone: 0

    anchors {
        bottom: true
        // left: true
        // right: true
    }

    // margins {
    //     bottom: 5
    // }

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!baseOsd.userInteracting) {
                baseOsd.visible = false;
            }
        }
    }

    function show() {
        baseOsd.visible = true;
        hideTimer.restart();
    }

    mask: Region {
        item: slider
    }

    Item {
        anchors.fill: parent

        Rectangle {
            // anchors.centerIn: parent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: 260 // 360
            height: 85
            radius: 21
            color: "transparent"

            StyledSlider {
                id: slider
                anchors.fill: parent
                anchors.margins: 6

                configuration: StyledSlider.Configuration.XL

                highlightColor: Colors.accent
                trackColor: Colors.surfaceContainerHighest
                handleColor: Colors.accent
                dotColor: Colors.accent
                dotColorHighlighted: Colors.accent
                handleMargins: 6

                insetIconColorActive: Colors.background
                insetIconColorInactive: Colors.text
                insetIconPadding: 10
                enableInsetIcon: true

                from: 0.0
                to: 1.0

                onPressedChanged: {
                    baseOsd.userInteracting = pressed;
                    if (pressed) {
                        hideTimer.stop();
                    } else {
                        hideTimer.restart();
                    }
                }

                onValueChanged: {
                    if (pressed) {
                        baseOsd.sliderMoved(value);
                    }
                }
            }
        }
    }
}
