import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import qs.services

QuickToggleButton {
    id: root
    toggled: !Audio.source?.audio?.muted
    visible: true

    contentItem: Item {
        implicitWidth: 24
        implicitHeight: 24

        CustomIcon {
            id: microphoneIcon
            source: root.toggled ? 'audio-input-microphone-symbolic' : 'microphone-disabled-symbolic'

            anchors.centerIn: parent
            width: 24
            height: 24
            colorize: true
            color: root.toggled ? Colors.background : Colors.text

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
        Audio.source.audio.muted = !Audio.source.audio.muted;
    }
}
