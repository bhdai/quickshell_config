import QtQuick

Rectangle {
    color: "#444444"
    width: 35
    height: 30
    radius: 15

    // notification component (placeholder)
    Text {
        id: notifText
        text: ""
        color: "white"
        font.pixelSize: 12
        anchors.centerIn: parent
    }
}
