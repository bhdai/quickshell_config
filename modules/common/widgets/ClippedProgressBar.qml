// ClippedProgressBar.qml
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * A progress bar with both ends rounded and text acts as a clipping mask,
 * similar to OneUI 7's battery indicator.
 */
ProgressBar {
    id: root
    property bool vertical: false
    property real valueBarWidth: 30
    property real valueBarHeight: 18
    property color highlightColor: "#FFFFFF"
    property color trackColor: "#F1D3F9"
    property alias radius: contentItem.radius
    property string text
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

    text: Math.round(value * 100)
    font {
        pixelSize: 13
        weight: text.length > 2 ? Font.Medium : Font.DemiBold
    }

    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Rectangle {
        id: contentItem
        anchors.fill: parent
        radius: 6
        color: root.trackColor
        visible: false

        Rectangle {
            id: progressFill
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: parent.width * root.visualPosition
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
            radius: contentItem.radius
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
