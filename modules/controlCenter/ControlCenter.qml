import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool isOpen: false
    property int desiredPanelWidth: 430
    property int desiredPanelHeight: 800
    // The window is the ceiling every panel below it shares — the toggles and sliders take a
    // fixed slice off the top, and a detail panel can only have what is left. The Wi-Fi panel's
    // network list and its subpage's dozen rows do not fit in that, so the window grows for it
    // alone; the Bluetooth panel and the notification list keep the room they had.
    property int desiredWifiPanelHeight: 950

    Loader {
        id: controlCenterLoader
        active: root.isOpen

        sourceComponent: PanelWindow {
            id: controlCenterPanel
            visible: root.isOpen

            exclusiveZone: 0
            implicitWidth: root.desiredPanelWidth
            // Safe to read the content's flag back into the window's size: it is a plain bool
            // set by a tap, not geometry, so nothing here feeds the height that feeds it.
            implicitHeight: content.wifiPanelOpen ? root.desiredWifiPanelHeight : root.desiredPanelHeight

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

                availableHeight: parent.height - anchors.margins * 2
            }

            mask: Region {
                Region {
                    item: content.topWindow
                }
                Region {
                    item: content.bottomWindow.item
                }
            }
        }
    }
}
