import Quickshell
import QtQuick
import qs.modules.dashboard

/**
 * Builds the dashboard card offscreen and measures it: the calendar at rest and after
 * navigating away from the current month, then the wallpaper grid on the other tab.
 *
 * Each destination names its own canvas and the card is the chrome around it, so what has to
 * be checked is that the card lands on the size the pane asked for, that it is a different
 * size on the other tab, and that nothing inside a pane is sized by what it happens to hold.
 * There is no display to look at it on, and #96's warning holds — an offscreen grab cannot
 * see masked or effect-backed drawing, so this asserts geometry and never pixels.
 *
 * The card rather than the window, because a layer surface cannot be built with no
 * Wayland session to build it on.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 900
        implicitHeight: 700
        visible: true

        DashboardCard {
            id: card
            tabs: [
                { key: "dashboard", label: "Dashboard", icon: "dashboard" },
                { key: "wallpaper", label: "Wallpaper", icon: "wallpaper" }
            ]
            currentTab: "dashboard"
        }

        // Where the indicator ended up, against the two lines it is supposed to be under.
        // Both are reported within the row, so a failure shows which way they drifted.
        function measureTabs(): string {
            const bar = card.tabBarItem;
            const tabs = [];
            // A tab is what knows whether it is the current destination. Its two lines are
            // Text items, which carry a contentWidth of their own.
            const walk = item => {
                if (item.active !== undefined && item.contentWidth !== undefined)
                    tabs.push(item);
                for (const child of item.children)
                    walk(child);
            };
            walk(bar);
            tabs.sort((first, second) => first.x - second.x);

            const indicator = bar.indicatorItem;
            const active = tabs.find(tab => tab.active);
            // The two lines together, which is the number the bar's height was built from.
            const lines = active.children.find(child => child.height > 0 && child.children.length === 2);
            return `TABS height=${bar.height} widths=${tabs.map(tab => Math.round(tab.width)).join(",")}` + ` lines=${Math.round(lines.height)}` + ` indicator=${Math.round(indicator.x)}+${Math.round(indicator.width)}@${indicator.height}` + ` active=${Math.round(active.contentX)}+${Math.round(active.contentWidth)}`;
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                const pane = card.paneItem;
                const calendar = pane.calendarColumn;

                // The day cells are the only items in the tree that carry a day, so this
                // counts what was actually built rather than trusting a Repeater's model.
                const cells = [];
                const walk = item => {
                    if (item.dayData !== undefined)
                        cells.push(item);
                    for (const child of item.children)
                        walk(child);
                };
                walk(calendar);

                const rows = new Set(cells.map(cell => Math.round(cell.mapToItem(calendar, 0, 0).y))).size;
                const widths = new Set(cells.map(cell => Math.round(cell.width)));
                const today = calendar.todayControl;

                // A day cell has to sit under its own weekday heading. Both are reported
                // as left edges within the card so one string can show them disagreeing.
                const lefts = item => [...new Set(item.children.filter(child => child.width > 0).map(child => Math.round(child.mapToItem(calendar, 0, 0).x)))].sort((a, b) => a - b);
                const columns = lefts(calendar.weekGrid.children.find(child => child.width > 0));
                const headings = lefts(calendar.weekdayHeadings);

                const measure = shift => {
                    pane.monthShift = shift;
                    return `${card.width}x${card.height}`;
                };

                // A weather tile is the only thing in the column carrying a symbol. Their
                // sizes are reported as a set, so six tiles that are not all one square
                // shape show up as more than one entry.
                const tiles = [];
                const walkTiles = item => {
                    if (item.symbol !== undefined)
                        tiles.push(item);
                    for (const child of item.children)
                        walkTiles(child);
                };
                walkTiles(pane.tileColumn);
                const tileSizes = [...new Set(tiles.map(tile => `${Math.round(tile.width)}x${Math.round(tile.height)}`))];

                // Nothing constrains or clips the band's two clusters, so a band too narrow
                // for both draws one over the other. Only the gap between them says so.
                const band = pane.band;
                const clusterGap = Math.round(band.readingCluster.mapToItem(band, 0, 0).x - (band.dateCluster.mapToItem(band, 0, 0).x + band.dateCluster.width));

                console.log(`DASHBOARD card=${card.width}x${card.height} pane=${pane.width}x${pane.height}` + ` band=${pane.band.width}x${pane.band.height} bandgap=${clusterGap} calendar=${calendar.x},${calendar.y} ${calendar.width}x${calendar.height}` + ` tiles=${pane.tileColumn.x},${pane.tileColumn.y} ${pane.tileColumn.width}x${pane.tileColumn.height}` + ` tilecount=${tiles.length} tilesizes=${tileSizes.join("/")}` + ` natural=${calendar.naturalHeight} cells=${cells.length} rows=${rows}` + ` today=${today.height}@${today.opacity}` + ` cellwidths=${[...widths].join("/")} columns=${columns.join(",")} headings=${headings.join(",")}`);

                // Navigating months must not resize anything, and the Today control must
                // hold its row rather than appear and shove the grid.
                const sizes = [measure(-1), measure(1), measure(7)];
                console.log(`DASHBOARD navigated=${sizes.join(",")} today=${today.height}@${today.opacity} natural=${calendar.naturalHeight}`);

                console.log(`${window.measureTabs()} on=dashboard`);

                card.currentTab = "wallpaper";
                gridTimer.restart();
            }
        }

        // The library is a live FolderListModel; the tiles it builds are not there on the
        // frame the tab switches.
        Timer {
            id: gridTimer

            interval: 500
            onTriggered: {
                const pane = card.paneItem;
                const grid = pane.cellGrid;

                const tiles = [];
                const walk = item => {
                    if (item.path !== undefined)
                        tiles.push(item);
                    for (const child of item.children)
                        walk(child);
                };
                walk(grid);

                const unique = values => [...new Set(values)].sort((a, b) => a - b);
                const at = (tile, axis) => Math.round(tile.mapToItem(grid, 0, 0)[axis]);
                const sizes = unique(tiles.map(tile => `${Math.round(tile.width)}x${Math.round(tile.height)}`));

                // Long enough after the switch that the indicator's move has landed.
                console.log(`${window.measureTabs()} on=wallpaper`);

                // Rows and columns as offsets within the grid rather than counts: a cell
                // that stretched, or a gap that changed, moves the ones after it.
                // A tile is applied by comparing its own path against what the service
                // committed, so this also proves the two strings are the same shape.
                const applied = tiles.filter(tile => tile.applied);

                console.log(`GRID card=${card.width}x${card.height} pane=${pane.width}x${pane.height}` + ` viewport=${pane.viewport.width}x${pane.viewport.height} content=${pane.viewport.contentHeight}` + ` tiles=${tiles.length} sizes=${sizes.join("/")}` + ` columns=${unique(tiles.map(tile => at(tile, "x"))).join(",")}` + ` rows=${unique(tiles.map(tile => at(tile, "y"))).join(",")}` + ` applied=${applied.length}:${applied.map(tile => tile.path).join(",")}` + ` empty=${pane.emptyMessage.visible} message=${JSON.stringify(pane.emptyMessage.text)}`);

                Qt.quit();
            }
        }
    }
}
