import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
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
        readonly property string iconColor: controlCenter.isOpen ? Colors.background : Colors.text

        implicitHeight: 30
        color: controlCenter.isOpen ? Colors.accent : (root.containsMouse ? Colors.surfaceHover : Colors.surface)
        radius: 15

        leftMargin: 10
        rightMargin: 10

        RowLayout {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            CustomIcon {
                source: Audio.symbol
                width: backgroundRect.iconSize
                height: backgroundRect.iconSize
                colorize: true
                color: backgroundRect.iconColor
            }

            CustomIcon {
                source: Network.symbol
                width: backgroundRect.iconSize
                height: backgroundRect.iconSize
                colorize: true
                color: backgroundRect.iconColor
            }

            CustomIcon {
                source: BluetoothStatus.connected ? "bluetooth-active-symbolic" : BluetoothStatus.enabled ? "bluetooth-disconnected-symbolic" : "bluetooth-disabled-symbolic"
                width: backgroundRect.iconSize
                height: backgroundRect.iconSize
                colorize: true
                color: backgroundRect.iconColor
            }
        }
    }

    ControlCenter {
        id: controlCenter
    }
}
