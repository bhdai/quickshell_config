import QtQuick

Item {
    id: root

    property real value: 0 // 0 to 1
    property color highlightColor: "#90caf9"
    property color trackColor: "#3d3d3d"

    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: parent.width * root.value
            height: parent.height
            radius: height / 2
            color: root.highlightColor
        }
    }
}
