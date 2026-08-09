import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/**
 * The tile grammar: an icon and label header, a large bare figure with its unit set small
 * beside it, then a caption that interprets the figure. The interpretation is the point —
 * "93%" alone does not say the day is oppressive.
 */
Rectangle {
    id: root

    property string symbol
    property string label
    property string figure
    property string unit
    property string caption
    // For the two tiles whose shape carries a reading: UV's scale and the sun's arc.
    default property alias extra: extraContainer.data
    // Painted under the text, corners and all, for the one tile that fills itself rather
    // than drawing a graphic inside its padding.
    property alias backdrop: backdropContainer.data

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small

    Item {
        id: backdropContainer
        anchors.fill: parent
    }

    Item {
        anchors.fill: parent
        anchors.margins: 10

        Row {
            id: head
            spacing: 4
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            // Filled and set on the surface's own foreground, not the variant tone: two of
            // these tiles paint under their header, and an outlined glyph in a dimmed colour
            // disappears into whatever is behind it.
            // 20 is the smallest optical master Material Symbols ships; below it the glyph is
            // that master scaled down, and the detailed ones here lose their strokes — `air`'s
            // three lines merge and `rainy`'s drops smear into a block.
            MaterialSymbol {
                id: glyph
                text: root.symbol
                iconSize: 24
                fill: 1
                color: Appearance.colors.colOnLayer2
                anchors.verticalCenter: parent.verticalCenter
            }

            // A label wider than the tile would otherwise run out over the one beside it
            // rather than being clipped by anything.
            Text {
                width: parent.width - glyph.width - parent.spacing
                elide: Text.ElideRight
                text: root.label
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            anchors.left: parent.left
            // Centred in the band the header and caption leave rather than hung off the
            // header: the tile is square and the figure is its subject, so sitting it high
            // reads as text that ran out of room rather than as the tile's reading.
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: (head.height - captionText.height) / 2
            spacing: 1

            Text {
                text: root.figure
                font.family: Appearance.font.family.main
                font.pixelSize: 40
                color: Appearance.colors.colOnLayer2
                anchors.bottom: parent.bottom
            }

            Text {
                text: root.unit
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
                anchors.bottom: parent.bottom
                // Lifted off the row's baseline so the unit sits with the figure's digits
                // rather than hanging under them; the offset tracks the figure's size.
                anchors.bottomMargin: 7
            }
        }

        // Fills the whole inner area rather than the gap under the figure, so a tile whose
        // shape carries the data can put it where that reading belongs — the compass in
        // the corner, the sun's arc across the middle.
        Item {
            id: extraContainer
            anchors.fill: parent
        }

        Text {
            id: captionText
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.caption
            elide: Text.ElideRight
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
    }
}
