import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.services
import "dashboard_metrics.js" as Metrics

/**
 * The wallpaper destination: the Wallpaper service's library as a scrolling grid of fixed
 * cells, flowing from the top left.
 *
 * The model is the singleton's one live enumerator rather than a second FolderListModel of
 * the same directory. Two of them would eventually disagree about what the library holds and
 * in what order, and then the grid and IPC cycling would be choosing from different lists.
 */
Item {
    id: root

    // What the offscreen geometry fixture measures. It cannot see the rounding or the
    // thumbnails, so what is left to check is that cells are a fixed size in fixed columns
    // and that an empty library is a message rather than an empty grid.
    readonly property alias viewport: viewport
    readonly property alias cellGrid: cellGrid
    readonly property alias emptyMessage: emptyMessage

    readonly property bool empty: Wallpaper.libraryModel.count === 0

    Flickable {
        id: viewport

        anchors.fill: parent
        visible: !root.empty
        clip: true
        contentHeight: cellGrid.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        // Grid rather than Flow: the row gap and the column gap are different numbers and
        // Flow has one spacing for both. Forcing them equal costs a whole row.
        Grid {
            id: cellGrid

            width: parent.width
            columns: Metrics.GRID_COLUMNS
            columnSpacing: Metrics.CELL_GAP_X
            rowSpacing: Metrics.CELL_GAP_Y

            Repeater {
                model: Wallpaper.libraryModel

                delegate: WallpaperTile {
                    required property url fileUrl

                    // Trimmed the way the service trims it, so a tile's identity is the same
                    // string the service compares its committed wallpaper against.
                    path: FileUtils.trimFileProtocol(fileUrl)
                }
            }
        }
    }

    Text {
        id: emptyMessage

        anchors.centerIn: parent
        width: parent.width - 2 * Metrics.PAD
        visible: root.empty
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
        // The filters the model actually applies, so this cannot claim a format the library
        // would then ignore.
        text: `No images in ${Wallpaper.library}\nAccepted: ${Wallpaper.libraryModel.nameFilters.join(", ")}`
    }
}
