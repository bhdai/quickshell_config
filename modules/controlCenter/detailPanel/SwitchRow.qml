import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * A detail panel's adapter row: label on the left, switch on the right, no leading icon.
 * `checked` is read from the adapter and `toggled()` asks the panel to flip it — the row
 * itself owns no state, so it stays truthful when the adapter changes elsewhere.
 *
 * Pressing anywhere on the row is the same as pressing the switch.
 */
Rectangle {
    id: root

    property string label
    property bool checked: false
    property color colBackground: Appearance.colors.colLayer1

    signal toggled

    implicitHeight: 56
    radius: Appearance.rounding.normal
    color: root.colBackground

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: 16
            right: switchControl.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        text: root.label
        color: Appearance.colors.colOnLayer1
        font.pixelSize: Appearance.font.pixelSize.normal
        elide: Text.ElideRight
    }

    StyledSwitch {
        id: switchControl
        anchors {
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        checked: root.checked
        onToggled: root.toggled()
    }
}
