import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell

QuickToggleButton {
    id: root
    toggled: false
    visible: true

    contentItem: Item {
        implicitWidth: 20
        implicitHeight: 20
        
        CustomIcon {
            id: cloudflareIcon
            source: 'cloudflare-dns-symbolic'

            anchors.centerIn: parent
            width: 20
            height: 20
            colorize: true
            color: root.toggled ? Colors.base : Colors.text

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
                }
            }
        }
    }

    onClicked: {
        if (toggled) {
            root.toggled = false;
        } else {
            root.toggled = true;
        }
    }
}
