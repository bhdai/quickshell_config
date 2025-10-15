import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.controlCenter
import qs.modules.common

WrapperMouseArea {
    id: root

    hoverEnabled: true

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            controlCenter.isOpen = !controlCenter.isOpen;
        }
    }

    WrapperRectangle {
        id: backgroundRect

        readonly property int iconSize: 20
        readonly property string iconColor: controlCenter.isOpen ? "black" : "white"

        implicitHeight: 30
        color: controlCenter.isOpen ? Colors.accent : (root.containsMouse ? Colors.surfaceHover : Colors.surface)
        radius: 15

        leftMargin: 10
        rightMargin: 10

        RowLayout {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            MaterialSymbol {
                text: Audio.materialSymbol
                iconSize: backgroundRect.iconSize
                fill: 1
                color: backgroundRect.iconColor
            }

            MaterialSymbol {
                text: Network.materialSymbol
                iconSize: backgroundRect.iconSize
                fill: 1
                color: backgroundRect.iconColor
            }

            MaterialSymbol {
                text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                iconSize: backgroundRect.iconSize
                color: backgroundRect.iconColor
            }
        }
    }

    ControlCenter {
        id: controlCenter
    }
}
