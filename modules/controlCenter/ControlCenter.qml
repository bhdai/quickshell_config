import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool isOpen: false
    property int desiredPanelWidth: 430
    // A ceiling, not a size. The content below is as tall as whichever panel is showing, and the
    // surplus is empty: the window's input mask is cut from the card and the panel, so the rest
    // of this height is click-through and invisible.
    //
    // The window itself must not be resized to follow the content. A layer surface is resized
    // asynchronously, so a panel whose height comes off the window's gets laid out against the
    // old height and then again, a frame or more later, against the new one, and that second
    // pass is a visible snap whenever a panel was already on screen to watch it. Holding the
    // surface still and moving only the items inside it is what lets the height animate.
    //
    // The floor is the tallest thing that must not scroll: the card, plus the Wi-Fi list at five
    // networks and the See-all row. Trimming much below 900 starts that list scrolling.
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
