import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.common.widgets

MouseArea {
    id: root

    required property SystemTrayItem modelData

    signal menuOpened()
    signal menuClosed()

    implicitWidth: 30
    implicitHeight: 30
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
        switch (mouse.button) {
        case Qt.LeftButton:
            modelData.activate();
            break;
        case Qt.RightButton:
            if (modelData.hasMenu) {
                menuLoader.active = true;
                menuLoader.item.open();
            }
            break;
        }
    }

    IconImage {
        id: trayIcon
        anchors.centerIn: parent
        source: root.modelData.icon
        width: root.implicitWidth * 0.7
        height: root.implicitHeight * 0.7
    }

    Tooltip {
        target: root
        side: Tooltip.Side.Below
        // Tray items expose a title and sometimes a one-line status string. Both go in the
        // plain chip, wrapped: a rich card for the items that happen to have a description
        // would give one strip of icons two different tooltips.
        text: {
            const title = root.modelData.tooltipTitle || root.modelData.title || root.modelData.id;
            const description = root.modelData.tooltipDescription;
            return description ? `${title}\n${description}` : title;
        }
    }

    Loader {
        id: menuLoader
        active: false

        sourceComponent: QsMenuAnchor {
            menu: root.modelData.menu

            anchor {
                window: root.QsWindow.window
                item: root
                edges: Edges.Bottom | Edges.Left
                gravity: Edges.Bottom | Edges.Left
            }

            Component.onCompleted: {
                root.menuOpened();
            }

            onClosed: {
                root.menuClosed();
                menuLoader.active = false;
            }
        }
    }
}
