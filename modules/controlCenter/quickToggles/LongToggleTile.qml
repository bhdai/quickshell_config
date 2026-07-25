import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Wide control-center tile: icon container, title, and a subtitle that marquees when it
 * overflows. Split into two targets — a press on the icon container emits `iconClicked()`,
 * a press anywhere else `bodyClicked()` — while the whole tile bounces either way, so the
 * split still reads as one button.
 *
 * ON fills the icon container with the accent colour and leaves the tile body dark, which is
 * the opposite of the icon-only quick toggles, where ON fills the whole button.
 */
GroupButton {
    id: root

    // Not `icon`: AbstractButton already owns that name as a FINAL grouped property.
    property string iconSource
    property string title
    property string subtitle

    signal iconClicked
    signal bodyClicked

    baseHeight: 60
    // A flat growth rather than GroupButton's edge-aware one: both tiles of a two-tile row sit
    // at an edge, and an enclosing ButtonGroup already halves what an edge button gains.
    clickedWidth: baseWidth + 16
    horizontalPadding: 12
    verticalPadding: 10
    buttonRadius: Appearance.rounding.normal
    buttonRadiusPressed: Appearance.rounding.small

    // Only the icon container carries the accent, so the body keeps its resting colours in the
    // toggled state instead of GroupButton's accent fill.
    colBackgroundToggled: Appearance.colors.colLayer2
    colBackgroundToggledHover: Appearance.colors.colLayer2Hover
    colBackgroundToggledActive: Appearance.colors.colLayer2Active

    onClicked: {
        // Everything left of the container's trailing edge is the icon target, so the leading
        // padding and the strip above and below the icon toggle too.
        const local = iconContainer.mapFromItem(root, root.pressPosition.x, root.pressPosition.y);
        if (local.x <= iconContainer.width)
            root.iconClicked();
        else
            root.bodyClicked();
    }

    contentItem: RowLayout {
        spacing: 10

        Rectangle {
            id: iconContainer
            implicitWidth: 40
            implicitHeight: 40
            radius: Appearance.rounding.full
            color: root.toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveEffects
                }
            }

            CustomIcon {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: root.iconSource
                colorize: true
                color: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.expressiveEffects
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.small
                font.bold: true
                elide: Text.ElideRight
            }

            Item {
                id: subtitleMarquee
                Layout.fillWidth: true
                implicitHeight: subtitleText.implicitHeight
                visible: root.subtitle.length > 0
                clip: true

                readonly property bool overflowing: subtitleText.implicitWidth > width
                readonly property real gap: 24
                readonly property real pixelsPerSecond: 40

                Row {
                    spacing: subtitleMarquee.gap

                    property real offset: 0

                    // The second copy trails one gap behind the first, so restarting the slide at
                    // exactly one text-plus-gap of travel puts it where the copy just was and the
                    // loop has no seam. Offset is animated and x bound to it, because animating x
                    // directly would drop the binding that parks the text when it fits.
                    x: subtitleMarquee.overflowing ? -offset : 0

                    NumberAnimation on offset {
                        running: subtitleMarquee.overflowing
                        loops: Animation.Infinite
                        from: 0
                        to: subtitleText.implicitWidth + subtitleMarquee.gap
                        duration: (subtitleText.implicitWidth + subtitleMarquee.gap) / subtitleMarquee.pixelsPerSecond * 1000
                    }

                    Text {
                        id: subtitleText
                        text: root.subtitle
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    Text {
                        visible: subtitleMarquee.overflowing
                        text: subtitleText.text
                        color: subtitleText.color
                        font: subtitleText.font
                    }
                }
            }
        }
    }
}
