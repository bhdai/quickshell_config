// Fixed numbers and fake readings for the dashboard layout spike. See README.md.
//
// Everything here is a constant on purpose: the spike answers "does this canvas hold
// these things", and a live service would make two runs of the same variant disagree.

.pragma library

// #87's canvas, unaltered. The spike exists to find out whether content actually fits it.
const CARD_W = 700;
const CARD_H = 507;
const PAD = 12;
const TABBAR_H = 48;
const GAP = 8;
const PANE_W = CARD_W - 2 * PAD;          // 676
const PANE_H = CARD_H - 2 * PAD - TABBAR_H - GAP;  // 427
const HEADER_H = 72;
const BODY_H = PANE_H - HEADER_H - GAP;   // 347
const COL_W = (PANE_W - PAD) / 2;         // 332

// A wallpaper thumbnail is a scaled-down screen, so the cell follows the panel this
// shell runs on (1920x1200) rather than a generic 16:9 — a 16:9 cell would crop the
// top and bottom off every wallpaper it is previewing.
const CELL_ASPECT = 1920 / 1200;

const GRIDS = [
    {
        key: "A",
        name: "4 wide, no footer",
        columns: 4,
        rowGap: 8,
        colGap: 12,
        footer: 0,
        note: "16 cells with no paging controls at all"
    },
    {
        key: "B",
        name: "3 wide, no footer",
        columns: 3,
        rowGap: 8,
        colGap: 12,
        footer: 0,
        note: "fewer, larger cells — the image is legible"
    },
    {
        key: "C",
        name: "4 wide, paged footer",
        columns: 4,
        rowGap: 8,
        colGap: 12,
        footer: 50,
        note: "Dank's shape: a 50px prev/indicator/next strip"
    }
];

function gridMetrics(grid) {
    const cellW = Math.floor((PANE_W - (grid.columns - 1) * grid.colGap) / grid.columns);
    const cellH = Math.round(cellW / CELL_ASPECT);
    const gridH = PANE_H - grid.footer;
    const rows = Math.floor((gridH + grid.rowGap) / (cellH + grid.rowGap));
    return {
        cellW: cellW,
        cellH: cellH,
        rows: rows,
        capacity: rows * grid.columns,
        gridH: gridH,
        // What is left over below the last full row. A large slack means the cell is
        // the wrong height for this pane, not that the grid is wrong.
        slack: gridH - (rows * cellH + (rows - 1) * grid.rowGap)
    };
}

const HEADERS = [
    { key: "1", name: "bare band" },
    { key: "2", name: "card band" },
    { key: "3", name: "weather-forward" }
];

// #84's probe readings, kept verbatim so the tiles show the numbers that argued for them
// — in particular the 6 degree gap between actual and apparent that won the first tile.
const WEATHER = {
    temp: 27,
    apparent: 33,
    condition: "Partly cloudy",
    icon: "partly_cloudy_day.svg",
    high: 33,
    low: 26,
    humidity: 93,
    windSpeed: 11,
    windDeg: 81,
    windCompass: "E",
    precipMm: 2.4,
    precipChance: 60,
    uv: 7,
    sunrise: "5:24",
    sunset: "18:32",
    // Fraction of the way from sunrise to sunset, for the arc's sun dot.
    dayProgress: 0.82
};

// 16 tiles for a library of two, as the ticket asks: the grid is being judged, not the
// library. The two real files repeat so the spike shows photographs at cell size, which
// is the only way to tell whether a cell is big enough to recognise a wallpaper in.
function tiles(home, count) {
    const sources = [home + "/Pictures/wall/leaves.jpg", home + "/Pictures/wall/moutains.jpg"];
    const out = [];
    for (let i = 0; i < count; i++) {
        out.push({
            source: sources[i % sources.length],
            name: (i % sources.length === 0 ? "leaves" : "moutains") + " " + (Math.floor(i / 2) + 1)
        });
    }
    return out;
}
