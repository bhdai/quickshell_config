import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common.widgets

MouseArea {
    id: root
    property bool borderless: true

    implicitWidth: batteryBody.implicitWidth
    // Taller than the body it wraps: this is the hover target, and the tooltip is easier to
    // reach with a little slack above and below the bar graphic.
    implicitHeight: 18

    hoverEnabled: true

    BatteryBody {
        id: batteryBody
        anchors.centerIn: parent

        percentage: Battery.percentage
        isCharging: Battery.isCharging
        isPluggedIn: Battery.isPluggedIn
        isCritical: Battery.isCritical
        foreground: "white"
    }

    Tooltip {
        target: root
        side: Tooltip.Side.Below
        variant: TooltipContainer.Variant.Rich
        contentComponent: batteryDetails
    }

    Component {
        id: batteryDetails
        BatteryDetails {}
    }
}
