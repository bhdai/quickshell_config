import QtQuick

// Power button component with dropdown menu
Rectangle {
    implicitWidth: 20
    implicitHeight: 20
    color: "red"
    radius: 4

    Text {
        anchors.centerIn: parent
        text: ""
        color: "white"
        font.pixelSize: 10
    }
}
