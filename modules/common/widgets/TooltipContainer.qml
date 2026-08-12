import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common

/**
 * The Material 3 tooltip's chrome, with no trigger and no placement of its own.
 *
 * Split out from `Tooltip` because two places in this shell need the look without the
 * behaviour: the slider value readout is driven by press rather than hover, and the session
 * screen's action label is driven by keyboard focus. Both drive their own `visible`; giving
 * `Tooltip` a manual show override instead would have turned it into a general popup, which
 * is what this component exists to stop.
 *
 * Sizes itself from its content. A rich container's shadow is drawn outside those bounds, so
 * whoever hosts one must leave `shadowMargin` of room around it — see `Tooltip`.
 */
Item {
    id: root

    enum Variant {
        Plain,
        Rich
    }

    property int variant: TooltipContainer.Variant.Plain
    property string text: ""
    /// Rich only, and optional — a rich container with no subhead is just wrapped body text.
    property string subhead: ""

    /**
     * Content to render instead of `subhead`/`text`, for the one case M3's two-string anatomy
     * cannot express: the battery readout's labelled rows with their own icons.
     *
     * It must not be interactive. Tooltips here dismiss the moment the pointer leaves the
     * anchor, so there is no way to reach anything inside one — a button here would be a
     * button nobody can press. It sizes itself; the 320px rich ceiling is the caller's to
     * respect.
     */
    property Component contentComponent: null

    readonly property bool rich: root.variant === TooltipContainer.Variant.Rich
    readonly property bool custom: root.contentComponent !== null
    /// Room a host must leave around this container for the elevation shadow to draw.
    readonly property real shadowMargin: root.rich ? Appearance.sizes.elevationMargin : 0

    implicitWidth: card.width
    implicitHeight: card.height

    Loader {
        // Material 3 gives the plain tooltip no elevation token at all; only rich sits at
        // level 2.
        active: root.rich
        anchors.fill: card
        sourceComponent: DropShadow {
            source: card
            horizontalOffset: 0
            verticalOffset: 2
            radius: 6
            samples: 13
            color: Appearance.colors.colShadow
        }
    }

    Rectangle {
        id: card

        readonly property real horizontalPadding: root.rich ? 16 : 8
        readonly property real topPadding: root.rich ? 12 : 4
        readonly property real bottomPadding: root.rich ? 8 : 4
        readonly property real maxWidth: root.rich ? 320 : 200

        readonly property Item body: root.custom ? customContent : content

        width: Math.max(root.rich ? 0 : 40, body.width + horizontalPadding * 2)
        height: Math.max(root.rich ? 0 : 24, body.implicitHeight + topPadding + bottomPadding)

        color: root.rich ? Appearance.colors.colSurfaceContainer : Appearance.colors.colTooltip
        radius: root.rich ? Appearance.rounding.small : Appearance.rounding.extraSmall

        Loader {
            id: customContent

            // Left to its own implicit size: forcing a width here would resize the item, and
            // an item whose own children fill that width would feed its new implicit width
            // straight back into this binding.
            active: root.custom
            sourceComponent: root.contentComponent
            x: card.horizontalPadding
            y: card.topPadding
        }

        ColumnLayout {
            id: content

            visible: !root.custom
            // Bound rather than anchored so the wrapped text drives the card's height.
            x: card.horizontalPadding
            y: card.topPadding
            width: Math.min(implicitWidth, card.maxWidth - card.horizontalPadding * 2)
            spacing: 0

            Text {
                // M3 titleSmall.
                visible: root.rich && root.subhead !== ""
                text: root.subhead
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smallPlus
                font.weight: Font.Medium
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
                elide: Text.ElideRight
                // The spec asks for a one-line subhead; the body below is where length goes.
                Layout.fillWidth: true
                Layout.preferredHeight: lineCount * lineHeight
            }

            Text {
                // M3 bodyMedium when rich, bodySmall when plain.
                text: root.text
                color: root.rich ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnTooltip
                font.family: Appearance.font.family.main
                font.pixelSize: root.rich ? Appearance.font.pixelSize.smallPlus : Appearance.font.pixelSize.smaller
                lineHeight: root.rich ? 20 : 16
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.Wrap
                horizontalAlignment: root.rich ? Text.AlignLeft : Text.AlignHCenter
                Layout.fillWidth: true
                // Height from Material 3's line box rather than from font metrics. Qt's
                // implicit height for a 12px line carries a pixel of leading past the 16px
                // box M3 specifies, which is enough to push the plain chip off its 24px
                // floor and make the padding wrong at every call site.
                Layout.preferredHeight: lineCount * lineHeight
            }
        }
    }
}
