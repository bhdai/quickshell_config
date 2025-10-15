import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common

WrapperMouseArea {
    id: root

    property alias icon: symbol.text
    property alias title: titleText.text
    property alias subtitle: subtitleText.text
    property bool toggled: false
    property color colToggleHover: ColorUtils.transparentize(Colors.accent, 0.2)

    implicitHeight: 60
    hoverEnabled: true

    onClicked: {
        root.toggled = !root.toggled;
    }

    Rectangle {
        anchors.fill: parent
        radius: 12

        color: root.toggled ? (root.containsMouse ? root.colToggleHover : Colors.accent) : (root.containsMouse ? Colors.surfaceHover : Colors.surface1)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 10

            MaterialSymbol {
                id: symbol
                iconSize: 24
                color: root.toggled ? Colors.base : Colors.text
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    id: titleText
                    color: root.toggled ? Colors.base : Colors.text
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    id: subtitleText
                    color: root.toggled ? Colors.base : Colors.subtext0
                    font.pixelSize: 12
                }
            }
        }
    }
}
