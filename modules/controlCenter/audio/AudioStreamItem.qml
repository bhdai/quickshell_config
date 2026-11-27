import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

/**
 * One app's playback stream: its name over a row of icon, volume slider and mute button.
 * `first` and `last` shape the corners, since the row cannot see its neighbours.
 */
Rectangle {
    id: root

    property PwNode node: null
    property bool first: false
    property bool last: false
    readonly property bool muted: root.node?.audio?.muted ?? false
    readonly property string label: Audio.streamLabel(root.node)

    readonly property real iconSize: 32
    readonly property real rowSpacing: 12

    implicitHeight: content.implicitHeight + 16
    topLeftRadius: root.first ? Appearance.rounding.normal : 4
    topRightRadius: root.first ? Appearance.rounding.normal : 4
    bottomLeftRadius: root.last ? Appearance.rounding.normal : 4
    bottomRightRadius: root.last ? Appearance.rounding.normal : 4
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 8
        }
        spacing: 0

        // The name sits above the controls rather than beside the icon, so the icon, slider and
        // mute button share one centre line. Indented to start where the slider starts.
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: root.iconSize + root.rowSpacing
            text: root.label
            color: root.muted ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.rowSpacing

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize

                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    implicitSize: root.iconSize
                    source: {
                        const iconName = Audio.streamIconName(root.node);
                        const named = iconName ? Quickshell.iconPath(iconName, true) : "";
                        if (named)
                            return named;
                        const guessed = AppSearch.guessIcon(root.label);
                        if (guessed && guessed !== "image-missing" && guessed !== "application-x-executable")
                            return Quickshell.iconPath(guessed, true);
                        return "";
                    }
                    visible: status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: "graphic_eq"
                    iconSize: 24
                    color: Appearance.colors.colOnLayer1
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                configuration: StyledSlider.Configuration.XS
                from: 0
                to: 1
                value: root.node?.audio?.volume ?? 0
                opacity: root.muted ? 0.5 : 1

                highlightColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colLayer3
                handleColor: Appearance.colors.colPrimary
                dotColor: Appearance.colors.colLayer3
                dotColorHighlighted: Appearance.colors.colLayer3

                onMoved: {
                    if (root.node?.audio)
                        root.node.audio.volume = value;
                }
            }

            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                implicitHeight: 40
                padding: 0
                buttonRadius: Appearance.rounding.full
                toggled: root.muted
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colPrimary

                onClicked: {
                    if (root.node?.audio)
                        root.node.audio.muted = !root.node.audio.muted;
                }

                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.muted ? "volume_off" : "volume_up"
                        iconSize: 20
                        color: root.muted ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
