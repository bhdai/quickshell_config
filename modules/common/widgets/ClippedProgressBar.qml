// ClippedProgressBar.qml
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    property real valueBarWidth: 30
    property real valueBarHeight: 18
    property color highlightColor: "#FFFFFF"
    property color trackColor: "#F1D3F9"
    property real radius: 6
    property string text
    property real value: 0
    property bool showNob: false
    property bool nobFilled: false

    property font font: Qt.font({
        pixelSize: 15,
        weight: text.length > 2 ? Font.Medium : Font.DemiBold
    })

    default property Item textMask: Item {
        width: valueBarWidth
        height: valueBarHeight
        Text {
            anchors.centerIn: parent
            text: root.text
            color: "white"
            font: root.font
        }
    }

    implicitWidth: valueBarWidth + (showNob ? 5 : 0)
    implicitHeight: valueBarHeight

    // Main battery body
    Item {
        id: batteryBody
        width: valueBarWidth
        height: valueBarHeight

        Rectangle {
            id: contentItem
            anchors.fill: parent
            radius: root.radius
            color: root.trackColor
            visible: false

            Rectangle {
                id: progressFill
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }
                // Fill extends beyond body to reach nob area
                width: Math.min(parent.width + (showNob ? 7 : 0), (parent.width + (showNob ? 7 : 0)) * root.value)
                height: parent.height
                color: root.highlightColor
                radius: 2
            }
        }

        // first mask: clip fill into rounded body
        OpacityMask {
            id: roundingMask
            anchors.fill: parent
            source: contentItem
            maskSource: Rectangle {
                width: contentItem.width
                height: contentItem.height
                radius: root.radius
            }
            visible: false
        }

        // second mask: text cut-out overlay
        OpacityMask {
            anchors.fill: parent
            source: roundingMask
            invert: true
            maskSource: root.textMask
        }
    }

    // Battery nob (terminal)
    Rectangle {
        id: batteryNob
        visible: showNob
        anchors {
            left: batteryBody.right
            leftMargin: 1
            verticalCenter: batteryBody.verticalCenter
        }
        width: 2
        height: batteryBody.height * 0.4
        radius: 1.5
        color: nobFilled ? root.highlightColor : root.trackColor
    }
}
