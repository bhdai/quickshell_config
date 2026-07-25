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
    property string trailingIcon: "applications-system-symbolic"
    // The row is bare by default; a filled row (Wi-Fi's connected pill) paints one background
    // behind both targets so the fill reads as a single shape rather than two buttons.
    property color colBackground: "transparent"
    property color colBackgroundHover: Appearance.colors.colLayer1Hover
    property color colDivider: Appearance.colors.colOutlineVariant
    property color colTrailing: Appearance.colors.colOnLayer1
    // The gear's own button already leaves 12px around its icon, which reads as enough on a
    // bare row. A filled row (Wi-Fi's pill) has a visible edge to clear, so it asks for more.
    property real trailingPadding: 0
    default property alias bodyData: bodySlot.data

    signal bodyClicked
    signal trailingClicked

    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: root.colBackground

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }
    }

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
        // Rest is the row's own fill rather than transparent: a target that fades in from
        // transparent crosses rgba(0,0,0,0) on its way, which flashes dark over a filled row.
        colBackground: root.colBackground
        colBackgroundHover: root.colBackgroundHover
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
        color: root.colDivider
    }

    RippleButton {
        id: gear

        anchors {
            right: parent.right
            rightMargin: root.trailingPadding
            verticalCenter: parent.verticalCenter
        }
        visible: root.trailingVisible
        padding: 0
        implicitWidth: 44
        implicitHeight: 44
        buttonRadius: Appearance.rounding.full
        colBackground: root.colBackground
        colBackgroundHover: root.colBackgroundHover
        colRipple: Appearance.colors.colPrimary

        onClicked: root.trailingClicked()

        // The icon centres inside a slot the Control sizes, rather than anchoring itself
        // against that same sizing — which is what pulled it off centre.
        contentItem: Item {
            CustomIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: root.trailingIcon
                colorize: true
                color: root.colTrailing
            }
        }
    }
}
