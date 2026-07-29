import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

/**
 * Avatar, username, and the resting copy that collapses away when the authentication area
 * reveals. Exactly one of these exists on a surface and it travels between the two
 * positions: two copies cross-faded would read as a swap rather than a movement, and would
 * load the same file twice.
 */
Column {
    id: root

    // The convention SDDM, GDM and LightDM already read, so one file drives the lock
    // screen and any future display manager rather than letting the two drift.
    readonly property url avatarSource: `${Directories.home}/.face`

    property bool detailsVisible: true

    spacing: Appearance.font.pixelSize.small

    ClippingRectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: Appearance.sizes.lockAvatar
        implicitHeight: Appearance.sizes.lockAvatar
        radius: width / 2
        color: Appearance.colors.colPrimaryContainer

        // Drawn under the image, so a missing or unreadable ~/.face is a themed circle
        // with a person in it rather than a broken image or a hole in the composition.
        MaterialSymbol {
            anchors.centerIn: parent
            visible: face.status !== Image.Ready
            text: "person"
            iconSize: Appearance.sizes.lockAvatar * 0.55
            fill: 1
            color: Appearance.colors.colOnPrimaryContainer
        }

        Image {
            id: face

            anchors.fill: parent
            source: root.avatarSource
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Quickshell.env("USER")
        color: Appearance.colors.colOnLayer0
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.large
        font.weight: Font.DemiBold
    }

    Item {
        id: details

        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: restingCopy.implicitWidth
        implicitHeight: root.detailsVisible ? restingCopy.implicitHeight : 0
        clip: true
        opacity: root.detailsVisible ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Appearance.animation.elementMoveSlow.duration
                easing.type: Appearance.animation.elementMoveSlow.type
                easing.bezierCurve: Appearance.animation.elementMoveSlow.bezierCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }

        Column {
            id: restingCopy

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.font.pixelSize.smallest / 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Locked"
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press any key or click to unlock"
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
