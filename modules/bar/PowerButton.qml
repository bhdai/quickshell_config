import QtQuick
import qs.modules.common.widgets

// Power button component with dropdown menu
Rectangle {
    implicitWidth: 30
    implicitHeight: 30
    radius: 4
    color: "transparent"

    MaterialSymbol {
        anchors.centerIn: parent
        text: "power_settings_new"
        iconSize: 20
        fill: 1
        color: "red"
    }
}
