import QtQuick
import qs.modules.common

/**
 * One line of a plot named in the colour and the stroke it is drawn in. Empty text is a
 * series the card does not have, and takes no room.
 */
Row {
    id: root

    property alias text: label.text
    // A number about this series and nothing else — a peak, a share, whatever the card is
    // stating per line. What window it belongs to is the legend's to say once, not each
    // key's to repeat.
    property alias value: valueLabel.text
    property color color: Appearance.colors.colPrimary
    // Whether the line this names is drawn dashed. Colour alone would under-report a plot
    // that distinguishes its series twice, and a reader who noticed the dash would come to
    // the legend to find two identical dots.
    property bool dashed: false

    spacing: 4
    visible: root.text !== ""

    // One footprint either way: a legend that changed width with the shape of its swatch
    // would shift the keys sideways for a reason that says nothing about the data.
    Item {
        implicitWidth: 8
        implicitHeight: 8
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            visible: !root.dashed
            radius: width / 2
            color: root.color
        }

        Row {
            anchors.centerIn: parent
            visible: root.dashed
            spacing: 2

            Rectangle {
                width: 3
                height: 2
                color: root.color
            }

            Rectangle {
                width: 3
                height: 2
                color: root.color
            }
        }
    }

    Text {
        id: label

        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer1
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        id: valueLabel

        visible: valueLabel.text !== ""
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer2
        anchors.verticalCenter: parent.verticalCenter
    }
}
