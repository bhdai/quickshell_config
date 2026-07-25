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
Item {
    id: root

    property string label
    property bool checked: false
    property color colBackground: Appearance.colors.colLayer1

    signal toggled

    implicitHeight: 56

    RippleButton {
        id: body

        anchors.fill: parent
        padding: 0
        buttonRadius: Appearance.rounding.normal
        colBackground: root.colBackground
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colPrimary

        onClicked: root.toggled()

        contentItem: Item {
            Text {
                anchors {
                    left: parent.left
                    leftMargin: 16
                    // The switch sits outside this content item, so the gap to it is a
                    // margin rather than an anchor against it.
                    right: parent.right
                    rightMargin: 16 + switchControl.width + 12
                    verticalCenter: parent.verticalCenter
                }
                text: root.label
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                elide: Text.ElideRight
            }
        }
    }

    // Sits outside the row's button, and after it, so the handle's drag reliably takes the
    // press. Inside the button's content item its stacking against the button's own mouse
    // area would decide that, and a swallowed press means no drag at all.
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
