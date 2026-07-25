import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * A detail-panel list row split into two press targets: the body, which performs the row's
 * primary action, and a trailing gear, which opens its details. The vertical divider is the
 * seam between them.
 *
 * Row content goes in the default slot and is parented into the body target; anchor it to
 * `parent`. The row's height is its own (`implicitHeight`) rather than the content's, so a
 * body item never binds its geometry back into the row that sizes it.
 */
Item {
    id: root

    property bool trailingVisible: true
    property string trailingSymbol: "settings"
    default property alias bodyData: bodySlot.data

    signal bodyClicked
    signal trailingClicked

    implicitHeight: 64

    RippleButton {
        id: body

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            right: root.trailingVisible ? divider.left : parent.right
            rightMargin: root.trailingVisible ? 8 : 0
        }
        padding: 0
        buttonRadius: Appearance.rounding.normal
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colPrimary

        onClicked: root.bodyClicked()

        contentItem: Item {
            id: bodySlot
        }
    }

    Rectangle {
        id: divider

        anchors {
            right: gear.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        visible: root.trailingVisible
        implicitWidth: 1
        implicitHeight: 24
        color: Appearance.colors.colOutlineVariant
    }

    RippleButton {
        id: gear

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        visible: root.trailingVisible
        padding: 0
        implicitWidth: 44
        implicitHeight: 44
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colPrimary

        onClicked: root.trailingClicked()

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: root.trailingSymbol
            iconSize: 20
            color: Appearance.colors.colOnLayer1
        }
    }
}
