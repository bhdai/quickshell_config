import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.modules.bar
import qs.modules.common
import qs.services

/**
 * SysTrayOverflowPopup - Popup displaying unpinned system tray items in a grid
 */
Scope {
    id: root

    property bool isOpen: false
    required property Item anchorItem

    // Expose the popup window for focus grab
    readonly property var popupWindow: popupLoader.active ? popupLoader.item : null

    // Forward menu signals from children
    signal menuOpened()
    signal menuClosed()

    Loader {
        id: popupLoader
        active: root.isOpen && TrayService.unpinnedItems.length > 0

        sourceComponent: PanelWindow {
            id: popupPanel
            visible: root.isOpen

            exclusiveZone: 0
            color: "transparent"

            // Calculate grid dimensions
            readonly property int itemCount: TrayService.unpinnedItems.length
            readonly property int itemSize: 36
            readonly property int gridSpacing: 8
            readonly property int gridPadding: 12
            readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(itemCount)))
            readonly property int rows: Math.ceil(itemCount / columns)

            implicitWidth: columns * itemSize + (columns - 1) * gridSpacing + gridPadding * 2 + 16
            implicitHeight: rows * itemSize + (rows - 1) * gridSpacing + gridPadding * 2 + 16

            WlrLayershell.namespace: "quickshell:systray-overflow"
            WlrLayershell.layer: WlrLayer.Overlay

            anchors {
                top: true
                right: true
            }

            // Position popup below the bar, aligned with anchor
            margins {
                top: 0
                right: {
                    const mapped = root.anchorItem.QsWindow?.mapFromItem(
                        root.anchorItem,
                        (root.anchorItem.width - popupPanel.implicitWidth) / 2, 0
                    );
                    if (mapped) {
                        const screenWidth = root.anchorItem.QsWindow?.window?.width || 1920;
                        return Math.max(10, screenWidth - mapped.x - popupPanel.implicitWidth);
                    }
                    return 10;
                }
            }

            // Background container
            Rectangle {
                id: popupBg
                anchors.fill: parent
                anchors.margins: 8
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.small
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: popupPanel.gridPadding
                    columns: popupPanel.columns
                    columnSpacing: popupPanel.gridSpacing
                    rowSpacing: popupPanel.gridSpacing

                    Repeater {
                        model: SystemTray.items

                        delegate: SysTrayItem {
                            visible: !TrayService.isPinned(modelData.id)
                            onMenuOpened: root.menuOpened()
                            onMenuClosed: root.menuClosed()
                        }
                    }
                }
            }
        }
    }
}
