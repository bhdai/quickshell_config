import QtQuick
import QtQuick.Controls

Button {
    id: root

    property real buttonRadius: 8
    property color colBackground: "#3d3d3d"
    property color colBackgroundHover: Qt.lighter(colBackground, 1.2)
    property color colRipple: Qt.lighter(colBackground, 1.4)
    default property alias content: contentContainer.data

    implicitWidth: 40
    implicitHeight: 40

    background: Rectangle {
        radius: root.buttonRadius
        color: root.hovered ? root.colBackgroundHover : root.colBackground

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    contentItem: Item {
        id: contentContainer
        anchors.fill: parent
    }
}
