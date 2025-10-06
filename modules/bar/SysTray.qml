import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.bar

WrapperRectangle {
    id: sysTrayWrapper

    color: "#444444"
    radius: 15

    leftMargin: 8
    rightMargin: 8

    RowLayout {
        id: trayIconsLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {

            model: SystemTray.items

            delegate: SysTrayItem {}
        }
    }
}
