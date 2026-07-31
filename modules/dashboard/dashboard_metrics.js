/**
 * The dashboard's fixed canvas, from #96 by way of the accepted prototype.
 *
 * The point of these being constants is that nothing in the dashboard may be sized by its
 * content: a month that needs a sixth row, a longer condition string, or a second tab must
 * all land on the same window. Everything below the card is derived, so padding stays a
 * single edit rather than three that have to agree.
 */

.pragma library

const MARGIN = 10;
const CARD_W = 700;
const CARD_H = 507;

const WINDOW_W = CARD_W + 2 * MARGIN;
const WINDOW_H = CARD_H + 2 * MARGIN;

const PAD = 12;
const TABBAR_H = 48;
const GAP = 8;

const PANE_W = CARD_W - 2 * PAD;
const PANE_H = CARD_H - 2 * PAD - TABBAR_H - GAP;

const HEADER_H = 72;
const BODY_H = PANE_H - HEADER_H - GAP;

const COL_GAP = PAD;
const COL_W = (PANE_W - COL_GAP) / 2;

// The pane's incoming content fades in over this. A named 0 is the supported hard cut.
const TAB_FADE_MS = 120;

// The wallpaper grid, Grid A of the accepted prototype.
//
// A thumbnail is a scaled-down screen, so the cell follows the aspect of the panel this
// shell runs on rather than a generic 16:9 — a 16:9 cell would crop the top and bottom off
// every wallpaper it is previewing.
const GRID_COLUMNS = 4;
const CELL_GAP_X = 12;
// Smaller than the column gap on purpose: at 12 only three rows of cells fit the pane.
const CELL_GAP_Y = 8;
const CELL_ASPECT = 1920 / 1200;
const CELL_W = (PANE_W - (GRID_COLUMNS - 1) * CELL_GAP_X) / GRID_COLUMNS;
const CELL_H = Math.round(CELL_W / CELL_ASPECT);
// How many rows the pane shows before it has to be scrolled.
const GRID_ROWS = Math.floor((PANE_H + CELL_GAP_Y) / (CELL_H + CELL_GAP_Y));
