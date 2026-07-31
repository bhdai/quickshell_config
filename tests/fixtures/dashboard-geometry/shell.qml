import Quickshell
import QtQuick
import qs.modules.dashboard

/**
 * Builds the dashboard card offscreen and measures it: the calendar at rest and after
 * navigating away from the current month, then the wallpaper grid on the other tab.
 *
 * The whole point of this surface is that it is fixed: nothing in it may be sized by its
 * content, so what has to be checked is not how it looks but what it measures. There is no
 * display to look at it on, and #96's warning holds — an offscreen grab cannot see masked
 * or effect-backed drawing, so this asserts geometry and never pixels.
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
        }

        // Where the indicator ended up, against the label it is supposed to be under. Both
        // are reported within the row, so a failure shows which way they drifted.
        function measureTabs(): string {
            const bar = card.tabBarItem;
            const labels = [];
            const walk = item => {
                if (item.labelWidth !== undefined)
                    labels.push(item);
                for (const child of item.children)
                    walk(child);
            };
            walk(bar);
            labels.sort((first, second) => first.x - second.x);

            const indicator = bar.indicatorItem;
            const active = labels.find(label => label.active);
            return `TABS height=${bar.height} widths=${labels.map(label => Math.round(label.width)).join(",")}` + ` indicator=${Math.round(indicator.x)}+${Math.round(indicator.width)}@${indicator.height}` + ` active=${Math.round(active.labelX)}+${Math.round(active.labelWidth)}`;
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

                console.log(`DASHBOARD card=${card.width}x${card.height} pane=${pane.width}x${pane.height}` + ` band=${pane.band.width}x${pane.band.height} calendar=${calendar.x},${calendar.y} ${calendar.width}x${calendar.height}` + ` tiles=${pane.tileColumn.x},${pane.tileColumn.y} ${pane.tileColumn.width}x${pane.tileColumn.height}` + ` natural=${calendar.naturalHeight} cells=${cells.length} rows=${rows}` + ` today=${today.height}@${today.opacity}` + ` cellwidths=${[...widths].join("/")} columns=${columns.join(",")} headings=${headings.join(",")}`);

                // Navigating months must not resize anything, and the Today control must
                // hold its row rather than appear and shove the grid.
                const sizes = [measure(-1), measure(1), measure(7)];
                console.log(`DASHBOARD navigated=${sizes.join(",")} today=${today.height}@${today.opacity} natural=${calendar.naturalHeight}`);

                console.log(`${window.measureTabs()} on=calendar`);

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
