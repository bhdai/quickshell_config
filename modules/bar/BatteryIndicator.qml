// BatteryIndicator.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.modules.services // assuming your Battery API lives here
import qs.modules.common.widgets

MouseArea {
    id: root
    property bool borderless: true
    readonly property real percentage: Battery.percentage
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isCritical: Battery.isCritical

    readonly property color fillColor: Battery.isCharging ? "#1BCA4B" : (Battery.isCritical ? "#F60B00" : "#FFFFFF")
    readonly property color trackColor: ColorUtils.transparentize(fillColor, 0.5) ?? "#F1D3F9"

    implicitWidth: 30
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
    }

    // bolt icon shown outside, not overlapping text
    MaterialSymbol {
        id: boltIcon
        anchors.left: batteryProgress.right
        anchors.leftMargin: 4
        anchors.verticalCenter: batteryProgress.verticalCenter
        iconSize: Appearance.font.pixelSize.smaller
        fill: 1
        text: "bolt"
        visible: isCharging && percentage < 1
    }
}
