import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * SysTray - System tray with pinned items inline and overflow popup for unpinned items
 */
MouseArea {
    id: root
    implicitWidth: backgroundRect.implicitWidth
    implicitHeight: 30
    hoverEnabled: true

    property bool trayOverflowOpen: false
    property bool menuActive: false

    function openMenu() {
        root.menuActive = true;
    }

    function closeMenu() {
        root.menuActive = false;
        // Re-grab focus for the popup if it's still open
        if (root.trayOverflowOpen) {
            focusGrab.active = true;
        }
    }

    onTrayOverflowOpenChanged: {
        if (root.trayOverflowOpen) {
            focusGrab.active = true;
        } else {
            focusGrab.active = false;
            root.menuActive = false;
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: overflowPopup.popupWindow ? [overflowPopup.popupWindow] : []
        onCleared: {
            // Don't close if a menu is active - the menu closing will re-grab
            if (root.menuActive) return;
            root.trayOverflowOpen = false;
        }
    }

    WrapperRectangle {
        id: backgroundRect
        implicitHeight: 30
        color: root.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1
        radius: 15

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        leftMargin: 8
        rightMargin: 8

        RowLayout {
            id: trayIconsLayout
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            // Pinned items - always visible inline
            Repeater {
                model: SystemTray.items

                delegate: SysTrayItem {
                    visible: TrayService.isPinned(modelData.id)
                    onMenuOpened: root.openMenu()
                    onMenuClosed: root.closeMenu()
                }
            }

            // Overflow button - only visible when unpinned items exist
            Loader {
                id: overflowButtonLoader
                active: TrayService.unpinnedItems.length > 0
                visible: active
                Layout.preferredWidth: active ? 30 : 0
                Layout.preferredHeight: active ? 30 : 0

                sourceComponent: MouseArea {
                    id: overflowButton
                    implicitWidth: 30
                    implicitHeight: 30
                    hoverEnabled: true

                    onClicked: {
                        root.trayOverflowOpen = !root.trayOverflowOpen;
                    }

                    CustomIcon {
                        anchors.centerIn: parent
                        source: "go-down-symbolic"
                        width: 16
                        height: 16
                        colorize: true
                        color: root.trayOverflowOpen ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0

                        rotation: root.trayOverflowOpen ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }
            }
        }
    }

    // Overflow popup for unpinned items
    SysTrayOverflowPopup {
        id: overflowPopup
        isOpen: root.trayOverflowOpen
        anchorItem: root

        onMenuOpened: root.openMenu()
        onMenuClosed: root.closeMenu()
    }
}
