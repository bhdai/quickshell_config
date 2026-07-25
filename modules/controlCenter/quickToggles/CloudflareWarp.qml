import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

QuickToggleButton {
    id: root

    contentItem: Item {
        implicitWidth: 24
        implicitHeight: 24

        CustomIcon {
            source: "cloudflare-dns-symbolic"

            anchors.centerIn: parent
            width: 24
            height: 24
            colorize: true
            color: root.colForeground

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveEffects
                }
            }
        }
    }

    toggled: WarpService.isActive

    onClicked: WarpService.toggle()
}
