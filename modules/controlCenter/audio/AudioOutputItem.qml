import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

/**
 * One output device in the audio panel's grouped list. Pressing it makes it the default sink.
 * `first` and `last` shape the corners, since the row cannot see its neighbours.
 */
RippleButton {
    id: root

    property PwNode node: null
    property bool first: false
    property bool last: false
    readonly property bool current: root.node !== null && root.node === Audio.sink

    implicitHeight: 64
    padding: 0
    topLeftRadius: root.first ? Appearance.rounding.normal : 4
    topRightRadius: root.first ? Appearance.rounding.normal : 4
    bottomLeftRadius: root.last ? Appearance.rounding.normal : 4
    bottomRightRadius: root.last ? Appearance.rounding.normal : 4
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colPrimary

    onClicked: {
        if (root.node && !root.current)
            Audio.setOutput(root.node);
    }

    contentItem: Item {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 16
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                implicitHeight: 40
                radius: width / 2
                color: root.current ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.expressiveEffects
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Audio.outputSymbol(root.node)
                    iconSize: 20
                    fill: root.current ? 1 : 0
                    color: root.current ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: Audio.outputLabel(root.node)
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.current
                    text: "Playing here"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.current
                text: "check"
                iconSize: 20
                color: Appearance.colors.colPrimary
            }
        }
    }
}
