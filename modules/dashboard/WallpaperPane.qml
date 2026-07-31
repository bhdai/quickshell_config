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

    property Item tabTarget: null
    property string focusedPath: ""
    property int focusedIndex: -1
    property bool gridFocused: false
    property bool initialRevealDone: false
    property bool reconcileScheduled: false

    // What the offscreen geometry fixture measures. It cannot see the rounding or the
    // thumbnails, so what is left to check is that cells are a fixed size in fixed columns
    // and that an empty library is a message rather than an empty grid.
    readonly property alias viewport: viewport
    readonly property alias cellGrid: cellGrid
    readonly property alias emptyMessage: emptyMessage

    readonly property bool empty: Wallpaper.libraryModel.count === 0

    function tileAt(index: int): Item {
        return index >= 0 && index < tiles.count ? tiles.itemAt(index) : null;
    }

    function pathAt(index: int): string {
        return root.tileAt(index)?.path ?? "";
    }

    function indexOfPath(path: string): int {
        for (let index = 0; index < tiles.count; ++index) {
            if (root.pathAt(index) === path)
                return index;
        }
        return -1;
    }

    function appliedIndex(): int {
        return root.indexOfPath(Wallpaper.wallpaper);
    }

    function revealIndex(index: int): void {
        const tile = root.tileAt(index);
        if (!tile)
            return;

        const top = tile.y;
        const bottom = top + tile.height;
        let target = viewport.contentY;
        if (top < target)
            target = top;
        else if (bottom > target + viewport.height)
            target = bottom - viewport.height;
        viewport.contentY = Math.max(0,
            Math.min(target, Math.max(0, viewport.contentHeight - viewport.height)));
    }

    function revealInitial(): void {
        if (root.initialRevealDone || Wallpaper.libraryModel.count === 0)
            return;
        const index = root.appliedIndex();
        viewport.contentY = 0;
        if (index >= 0)
            root.revealIndex(index);
        root.initialRevealDone = true;
    }

    function focusIndex(index: int): bool {
        const tile = root.tileAt(index);
        if (!tile)
            return false;
        root.focusedPath = tile.path;
        root.focusedIndex = index;
        root.gridFocused = true;
        tile.forceActiveFocus();
        root.revealIndex(index);
        return true;
    }

    function focusEntry(): bool {
        if (Wallpaper.libraryModel.count === 0)
            return false;
        const applied = root.appliedIndex();
        return root.focusIndex(applied >= 0 ? applied : 0);
    }

    function moveFocus(direction: string): bool {
        if (!root.gridFocused || root.focusedIndex < 0)
            return false;

        const index = root.focusedIndex;
        const column = index % Metrics.GRID_COLUMNS;
        let target = index;
        switch (direction) {
        case "left":
            if (column === 0)
                return false;
            target--;
            break;
        case "right":
            if (column === Metrics.GRID_COLUMNS - 1
                    || index + 1 >= Wallpaper.libraryModel.count)
                return false;
            target++;
            break;
        case "up":
            if (index < Metrics.GRID_COLUMNS)
                return false;
            target -= Metrics.GRID_COLUMNS;
            break;
        case "down":
            if (index + Metrics.GRID_COLUMNS >= Wallpaper.libraryModel.count)
                return false;
            target += Metrics.GRID_COLUMNS;
            break;
        default:
            return false;
        }
        return root.focusIndex(target);
    }

    function activateFocused(): bool {
        const tile = root.tileAt(root.focusedIndex);
        if (!root.gridFocused || !tile)
            return false;
        tile.activate();
        return true;
    }

    function returnFocusToTab(): bool {
        if (!root.tabTarget)
            return false;
        root.gridFocused = false;
        root.focusedPath = "";
        root.focusedIndex = -1;
        return root.tabTarget.focusCurrentTab();
    }

    function scheduleReconcile(): void {
        if (!root.gridFocused || root.reconcileScheduled)
            return;
        root.reconcileScheduled = true;
        Qt.callLater(root.reconcileFocus);
    }

    function reconcileFocus(): void {
        root.reconcileScheduled = false;
        if (!root.gridFocused)
            return;
        if (Wallpaper.libraryModel.count === 0) {
            root.returnFocusToTab();
            return;
        }

        const samePath = root.indexOfPath(root.focusedPath);
        if (samePath >= 0) {
            root.focusIndex(samePath);
            return;
        }
        root.focusIndex(Math.min(root.focusedIndex, Wallpaper.libraryModel.count - 1));
    }

    Component.onCompleted: Qt.callLater(root.revealInitial)

    Connections {
        target: Wallpaper.libraryModel
        function onCountChanged(): void {
            if (!root.initialRevealDone)
                Qt.callLater(root.revealInitial);
            root.scheduleReconcile();
        }
    }

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
                id: tiles
                model: Wallpaper.libraryModel
                onItemAdded: root.scheduleReconcile()
                onItemRemoved: root.scheduleReconcile()

                delegate: WallpaperTile {
                    required property int index
                    required property url fileUrl

                    // Trimmed the way the service trims it, so a tile's identity is the same
                    // string the service compares its committed wallpaper against.
                    tileIndex: index
                    path: FileUtils.trimFileProtocol(fileUrl)
                    onFocusClaimed: (tileIndex, tilePath) => {
                        root.focusedPath = tilePath;
                        root.focusedIndex = tileIndex;
                        root.gridFocused = true;
                        root.revealIndex(tileIndex);
                    }
                    onMoveRequested: direction => root.moveFocus(direction)
                    onTabRequested: root.returnFocusToTab()
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
