import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool isOpen: false
    property int panelWidth: 420
    property int panelHeight: 800

    Loader {
        id: controlCenterLoader
        active: root.isOpen

        sourceComponent: PanelWindow {
            id: controlCenterPanel
            visible: root.isOpen

            exclusiveZone: 0
            implicitWidth: root.panelWidth
            implicitHeight: root.panelHeight
            WlrLayershell.namespace: "quickshell:controlCenter"
            color: "transparent"

            anchors {
                top: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [controlCenterPanel]
                active: controlCenterLoader.active
                onCleared: () => {
                    if (!active) {
                        root.isOpen = false;
                    }
                }
            }

            ControlCenterContent {
                id: content
                anchors.fill: parent
                anchors.margins: 10
            }
        }
    }
}
