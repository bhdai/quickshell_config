import QtQuick

Item {
    id: root

    property real value: 0 // 0 to 1
    property color highlightColor: "#90caf9"
    property color trackColor: "#3d3d3d"
    property color handleColor: "#90caf9"

    signal moved(real value)

    implicitHeight: 20

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: parent.width
        height: 6
        radius: height / 2
        color: root.trackColor

        Rectangle {
            id: progress
            width: parent.width * root.value
            height: parent.height
            radius: height / 2
            color: root.highlightColor
        }
    }

    Rectangle {
        id: handle
        x: (root.width - width) * root.value
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: width / 2
        color: root.handleColor
        border.color: Qt.lighter(color, 1.2)
        border.width: 2
        visible: mouseArea.containsMouse || mouseArea.pressed

        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        onPressed: mouse => {
            let newValue = Math.max(0, Math.min(1, mouse.x / width));
            root.value = newValue;
            root.moved(newValue);
        }

        onPositionChanged: mouse => {
            if (pressed) {
                let newValue = Math.max(0, Math.min(1, mouse.x / width));
                root.value = newValue;
                root.moved(newValue);
            }
        }

        onContainsMouseChanged: {
            if (containsMouse) {
                handle.width = 20;
                handle.height = 20;
            } else if (!pressed) {
                handle.width = 16;
                handle.height = 16;
            }
        }
    }
}
