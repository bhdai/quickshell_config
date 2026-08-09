import QtQuick
import qs.modules.common

/**
 * One line of a plot named in the colour it is drawn in. Empty text is a series the card
 * does not have, and takes no room.
 */
Row {
    id: root

    property alias text: label.text
    property color color: Appearance.colors.colPrimary

    spacing: 4
    visible: root.text !== ""

    Rectangle {
        width: 8
        height: 8
        radius: width / 2
        color: root.color
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        id: label

        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer1
        anchors.verticalCenter: parent.verticalCenter
    }
}
