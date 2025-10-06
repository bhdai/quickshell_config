import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

MouseArea {
    id: root

    required property SystemTrayItem modelData

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
                // openMenu();
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

    Loader {
        id: tooltipLoader
        active: root.containsMouse && root.QsWindow && root.QsWindow.window

        sourceComponent: SysTrayItemTooltip {
            item: root.modelData
            anchorItem: root
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

            onClosed: menuLoader.active = false
        }
    }
}
