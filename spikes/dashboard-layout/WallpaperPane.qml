import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.common.widgets
import "mock.js" as Mock

// The wallpaper tab on #87's 676x427 pane. #86 fixed that cells are a fixed size flowing
// from the top left with no filler tiles; what is being judged here is that size.
Item {
    id: root

    property var grid: Mock.GRIDS[0]
    readonly property var metrics: Mock.gridMetrics(grid)
    // The ticket asks for 16 tiles against a real library of two, because the grid is the
    // subject and the library is not.
    readonly property var model: Mock.tiles(Quickshell.env("HOME"), 16)

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.metrics.gridH
        clip: true
        interactive: root.grid.footer === 0
        contentHeight: flow.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        // Grid rather than Flow: the row gap and the column gap are different numbers, and
        // Flow has one spacing for both. Forcing them equal costs a whole row — at a 12px
        // row gap only three rows of 100px cells fit in 427, where an 8px gap fits four.
        Grid {
            id: flow
            width: parent.width
            columns: root.grid.columns
            rowSpacing: root.grid.rowGap
            columnSpacing: root.grid.colGap

            Repeater {
                // A paged variant shows one page; a scrolling one shows the lot. Paging
                // mechanics are not the question — the footer's cost in height is.
                model: root.grid.footer > 0 ? root.metrics.capacity : root.model.length

                delegate: Item {
                    required property int index
                    width: root.metrics.cellW
                    height: root.metrics.cellH

                    // Bounded decode inside, per #90's finding that sourceSize with both
                    // dimensions set scales to cover — a 5K JPEG at cell size otherwise
                    // costs its full unbounded texture, sixteen times over.
                    RoundedImage {
                        width: root.metrics.cellW
                        height: root.metrics.cellH
                        radius: Appearance.rounding.small
                        surround: Appearance.colors.colLayer0
                        source: root.model[index].source
                    }

                    // The current wallpaper. #86 allows it to be absent entirely, so this
                    // must be a ring on a tile rather than a state the grid always has.
                    Rectangle {
                        visible: index === 0
                        width: root.metrics.cellW
                        height: root.metrics.cellH
                        radius: Appearance.rounding.small
                        color: "transparent"
                        border.width: 3
                        border.color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }

    // Dank's paging strip, shown only by the variant that pays for it.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.grid.footer
        visible: root.grid.footer > 0

        Row {
            anchors.centerIn: parent
            spacing: 12

            MaterialSymbol {
                text: "chevron_left"
                iconSize: 20
                color: Appearance.colors.colOnLayer1
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: Math.ceil(root.model.length / root.metrics.capacity)
                    delegate: Rectangle {
                        required property int index
                        width: 7
                        height: 7
                        radius: 3.5
                        color: index === 0 ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                    }
                }
            }

            MaterialSymbol {
                text: "chevron_right"
                iconSize: 20
                color: Appearance.colors.colOnLayer1
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
