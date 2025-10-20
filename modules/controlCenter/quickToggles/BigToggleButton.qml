import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common

WrapperMouseArea {
    id: root

    property alias icon: symbol.source
    property alias title: titleText.text
    property alias subtitle: subtitleText.text
    property bool toggled: false
    property color colToggleHover: ColorUtils.transparentize(Colors.accent, 0.2)

    property bool bounce: true
    property real baseRadius: 12
    property real pressedRadius: 10
    property real baseWidth: 0
    property real expandWidth: 8  // how much wider when pressed

    implicitHeight: 60
    hoverEnabled: true

    Layout.fillWidth: true
    Layout.preferredWidth: pressed && bounce ? baseWidth + expandWidth : baseWidth

    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]  // expressiveFastSpatial curve
        }
    }

    onClicked: {
        root.toggled = !root.toggled;
    }

    Rectangle {
        anchors.fill: parent
        radius: pressed && bounce ? pressedRadius : baseRadius

        color: root.toggled ? (root.containsMouse ? root.colToggleHover : Colors.accent) : (root.containsMouse ? Colors.surfaceHover : Colors.surface1)

        Behavior on radius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]  // expressiveEffects curve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 10

            CustomIcon {
                id: symbol
                width: 24
                height: 24
                colorize: true
                color: root.toggled ? Colors.background : Colors.text
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
                    visible: toggled
                }
            }
        }
    }
}
