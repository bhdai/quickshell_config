/**
 * The dashboard's chrome, and the canvas each destination asks for inside it.
 *
 * The card is chrome around whichever pane is showing, so a destination names its own pane
 * size and the card, the window and the move between them all follow. Only the chrome is
 * shared; nothing here is a canvas every tab has to agree on.
 *
 * What has not changed is that a pane is a fixed size. Within a destination nothing may be
 * sized by its content: a month that needs a sixth row, a longer condition string or a
 * sparse library must all land on the canvas its tab named. Sizing a pane from what it
 * happens to hold puts the whole window on a spring.
 *
 * A new destination is a section below, an entry in CANVAS, a pane that takes its implicit
 * size from that entry, and a name in the card's tab list.
 */

.pragma library

// The chrome every destination sits in: the window's outer margin, the card's padding, the
// tab bar and the gap under it.
const MARGIN = 10;
const PAD = 12;
// Two lines rather than one: a 24px icon over a 15px label measures 49 in this font, which
// with 6px above and below and the 3px indicator lane is M3's icon-and-label tab height
// exactly rather than padded up to it. Every destination's card carries this, so moving it
// moves every pane down and rebakes WINDOW_H.
const TABBAR_H = 64;
const GAP = 8;

// What the card adds around a pane of a given size. The window is this plus MARGIN on
// every edge.
function cardWidth(paneWidth) {
    return paneWidth + 2 * PAD;
}

function cardHeight(paneHeight) {
    return paneHeight + 2 * PAD + TABBAR_H + GAP;
}

// --- Calendar: a full-width band over `calendar | weather tiles` ---

const HEADER_H = 72;
const COL_GAP = PAD;

// The weather tiles are square, and their edge is the number the rest of this destination is
// built from: six of them in three columns of two fix both the tile column's width and the
// body's height, and through the body the size of the whole tab.
//
// The edge is not free to pick. The calendar shares BODY_H and needs a little under 348px
// for six week rows, so with two rows of tiles the edge is pinned near half of that. Laying
// the six out wide rather than tall is what buys them the size — a tile small enough to keep
// the old width would leave the calendar rattling around in a body built for nothing.
const TILE = 168;
const TILE_COL_W = 3 * TILE + 2 * COL_GAP;
const BODY_H = 2 * TILE + COL_GAP;

// The calendar keeps the width it had when the two columns were equal halves of a 700px
// card — squaring the tiles is what takes this destination narrower, not squeezing the
// month. Seven day columns are divided out of this, so it is the number to move if the
// calendar should be tighter still.
const CALENDAR_COL_W = 332;

const CALENDAR_PANE_W = CALENDAR_COL_W + COL_GAP + TILE_COL_W;
const CALENDAR_PANE_H = HEADER_H + GAP + BODY_H;


// --- Wallpaper: the library as a scrolling grid of fixed cells ---

// A thumbnail is a scaled-down screen, so the cell follows the aspect of the panel this shell
// runs on rather than a generic 16:9 — a 16:9 cell would crop the top and bottom off every
// wallpaper it is previewing.
const CELL_ASPECT = 1920 / 1200;
const CELL_W = 160;
const CELL_H = Math.round(CELL_W / CELL_ASPECT);
const CELL_GAP_X = 12;
// Smaller than the column gap on purpose: at 12 a fourth row costs more height than it is
// worth against the calendar beside it.
const CELL_GAP_Y = 8;

// The grid is what this destination is, so the pane is exactly the cells it shows rather
// than a leftover. A library longer than this scrolls.
const GRID_COLUMNS = 4;
const GRID_ROWS = 4;

const WALLPAPER_PANE_W = GRID_COLUMNS * CELL_W + (GRID_COLUMNS - 1) * CELL_GAP_X;
const WALLPAPER_PANE_H = GRID_ROWS * CELL_H + (GRID_ROWS - 1) * CELL_GAP_Y;

// --- Performance: four cards dividing a fixed canvas ---

const PERFORMANCE_PANE_W = 872;
const PERFORMANCE_PANE_H = 428;

// The gap between two cards on this destination. Deliberately not a universal inner-card
// padding rule — it is how this pane is divided, and nothing outside it is measured from it.
const CARD_GAP = PAD;

// Two rows, and a top row of two cards of equal status: neither CPU nor memory is the
// metric the other is read against. The bottom row divides unevenly, which is why its cards
// name their own widths when they arrive rather than deriving from this.
const PERFORMANCE_ROW_H = (PERFORMANCE_PANE_H - CARD_GAP) / 2;
const PERFORMANCE_TOP_CARD_W = (PERFORMANCE_PANE_W - CARD_GAP) / 2;

// What an inner card holds its content in, away from its own rounded edge.
const PERFORMANCE_CARD_PAD = 12;

// Every card's rectangle in the pane, so that a card is placed by name rather than by an
// inline size written next to it.
const PERFORMANCE_CARD = {
    cpu: {
        x: 0,
        y: 0,
        width: PERFORMANCE_TOP_CARD_W,
        height: PERFORMANCE_ROW_H
    },
    memory: {
        x: PERFORMANCE_TOP_CARD_W + CARD_GAP,
        y: 0,
        width: PERFORMANCE_TOP_CARD_W,
        height: PERFORMANCE_ROW_H
    }
};

// --- The window every destination is drawn into ---

// Every canvas in one place, because the window has to be the largest of them. A pane reads
// its own entry rather than being told a size, so a destination cannot ask for a canvas the
// window was not sized for.
const CANVAS = {
    dashboard: {
        width: CALENDAR_PANE_W,
        height: CALENDAR_PANE_H
    },
    wallpaper: {
        width: WALLPAPER_PANE_W,
        height: WALLPAPER_PANE_H
    },
    performance: {
        width: PERFORMANCE_PANE_W,
        height: PERFORMANCE_PANE_H
    }
};

const TRACK_START = {
    dashboard: 0,
    wallpaper: CANVAS.dashboard.width,
    performance: CANVAS.dashboard.width + CANVAS.wallpaper.width
};
const TRACK_W = Object.values(CANVAS).reduce((width, canvas) => width + canvas.width, 0);

// The window is the largest destination and then stays there — deliberately not the card it
// happens to be showing. A layer surface bound to an animating size re-commits and is
// re-centred by the compositor on every frame of the move, which is visible as a flicker
// around the edges. Holding the surface still and letting the card resize inside it costs a
// transparent border on the narrower tabs, which the mask makes click-through anyway.
const WINDOW_W = Math.max(...Object.values(CANVAS).map(canvas => cardWidth(canvas.width))) + 2 * MARGIN;
const WINDOW_H = Math.max(...Object.values(CANVAS).map(canvas => cardHeight(canvas.height))) + 2 * MARGIN;
