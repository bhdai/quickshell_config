import QtQuick
import qs.modules.common

// PROTOTYPE — throwaway. The prototype's own control, not a candidate for anything.
Rectangle {
    id: chip

    property string label: ""
    property bool checked: false
    signal clicked

    implicitWidth: text.implicitWidth + 24
    implicitHeight: 32
    radius: height / 2
    color: chip.checked ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
    border.color: Appearance.colors.colOutlineVariant
    border.width: 1

    Text {
        id: text
        anchors.centerIn: parent
        text: chip.label
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: chip.checked ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
