import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.modules.services
import qs.modules.common.widgets

MouseArea {
    id: root
    property bool borderless: true
    readonly property real percentage: Battery.percentage
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isCritical: Battery.isCritical
    property real boltSize: 16

    readonly property color fillColor: Battery.isCharging ? "#1BCA4B" : (Battery.isCritical ? "#F60B00" : "#FFFFFF")
    readonly property color trackColor: ColorUtils.transparentize("#FFFFFF", 0.5) ?? "#F1D3F9"

    implicitWidth: batteryProgress.implicitWidth + (isCharging && percentage < 1 ? boltIcon.width + 2 : 0)
    implicitHeight: 18

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        width: valueBarWidth
        height: valueBarHeight
        value: percentage
        highlightColor: root.fillColor
        trackColor: root.trackColor
        text: Math.round(percentage * 100)
        showNob: !isCharging || percentage >= 1
        nobFilled: percentage >= 1
    }

    // bolt icon replaces nob when charging
    Item {
        id: boltIcon
        anchors.left: batteryProgress.right
        anchors.leftMargin: -6
        anchors.verticalCenter: batteryProgress.verticalCenter
        width: root.boltSize
        height: root.boltSize
        visible: isCharging && percentage < 1

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: parent.width
            fill: 1
            text: "bolt"
            color: "white"
        }
    }
}
