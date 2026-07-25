import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool isOpen: false
    property int desiredPanelWidth: 430
    // The window is the ceiling every panel below it shares — the toggles and sliders take a
    // fixed slice off the top, and a detail panel gets what is left, which is this minus 306
    // (the card, the window margins, and the spacing between the two). The Wi-Fi list is what
    // sets the floor: five networks and the See-all row want about 600, so trimming much below
    // 900 starts the list scrolling. Sized once and never resized per panel — a layer surface
    // is resized asynchronously, so a panel whose height comes off the window's gets laid out
    // against the old height and then again, a frame or more later, against the new one, and
    // that second pass is a visible snap whenever a panel was already on screen to watch it.
    property int desiredPanelHeight: 900

    Loader {
        id: controlCenterLoader
        active: root.isOpen

        sourceComponent: PanelWindow {
            id: controlCenterPanel
            visible: root.isOpen

            exclusiveZone: 0
            implicitWidth: root.desiredPanelWidth
            implicitHeight: root.desiredPanelHeight

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
