import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const { weekDays, checkLeapYear, getMonthDays, getDateInXMonthsTime, getDayOfWeekMondayFirst, getCalendarLayout } = loadQmlJs(path.join(repoRoot, "modules", "dashboard", "calendar_layout.js"), ["weekDays", "checkLeapYear", "getMonthDays", "getDateInXMonthsTime", "getDayOfWeekMondayFirst", "getCalendarLayout"]);

// The grid is a fixed six rows against a fixed-height card, so a month that needs a
// seventh row would silently lose days and one that needs five would leave a gap.
const cells = grid => grid.flat();
const days = grid => cells(grid).map(cell => cell.day);

test("the week starts on Monday and ends on Sunday", () => {
    assert.deepEqual(weekDays.map(entry => entry.day), ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]);
});

test("Sunday is the last column, not the first", () => {
    // 2026-02-01 is a Sunday, 2026-02-02 a Monday.
    assert.equal(getDayOfWeekMondayFirst(new Date(2026, 1, 1)), 6);
    assert.equal(getDayOfWeekMondayFirst(new Date(2026, 1, 2)), 0);
});

test("a month always fills exactly six rows of seven cells", () => {
    // February 2026 starts on a Sunday, so its 28 days span six rows here where a
    // Sunday-first calendar would need only five.
    for (const viewDate of [new Date(2026, 1, 1), new Date(2026, 6, 1), new Date(2025, 11, 1)]) {
        const grid = getCalendarLayout(viewDate, false);
        assert.equal(grid.length, 6);
        for (const week of grid)
            assert.equal(week.length, 7);
        assert.equal(cells(grid).length, 42);
    }
});

test("the first of the month lands in its Monday-first column", () => {
    // 2026-07-01 is a Wednesday: two leading cells from June.
    const grid = getCalendarLayout(new Date(2026, 6, 1), false);
    assert.deepEqual(grid[0], [
        { day: "29", today: -1 },
        { day: "30", today: -1 },
        { day: "1", today: 0 },
        { day: "2", today: 0 },
        { day: "3", today: 0 },
        { day: "4", today: 0 },
        { day: "5", today: 0 }
    ]);
});

test("leading and trailing cells come from the neighbouring months", () => {
    const grid = getCalendarLayout(new Date(2026, 6, 1), false);
    const flat = cells(grid);

    // June has 30 days and July 31, so the fill runs 29, 30 then 1 … 31 then 1 …
    assert.deepEqual(days(grid).slice(0, 2), ["29", "30"]);
    assert.equal(flat[2].today, 0);
    assert.deepEqual(days(grid).slice(2, 33), Array.from({ length: 31 }, (_, i) => String(i + 1)));
    assert.deepEqual(days(grid).slice(33), ["1", "2", "3", "4", "5", "6", "7", "8", "9"]);
    for (const cell of flat.slice(33))
        assert.equal(cell.today, -1);
});

test("January borrows from the previous December", () => {
    // 2026-01-01 is a Thursday, so three cells of December 2025 lead it.
    const grid = getCalendarLayout(new Date(2026, 0, 1), false);
    assert.deepEqual(days(grid).slice(0, 4), ["29", "30", "31", "1"]);
});

test("leap years give February a 29th", () => {
    assert.equal(checkLeapYear(2024), true);
    assert.equal(checkLeapYear(2026), false);
    assert.equal(checkLeapYear(1900), false);
    assert.equal(checkLeapYear(2000), true);

    assert.equal(getMonthDays(1, 2024), 29);
    assert.equal(getMonthDays(1, 2026), 28);
    assert.equal(getMonthDays(1, 1900), 28);
    assert.equal(getMonthDays(1, 2000), 29);
});

test("a leap February's 29th is a current-month cell", () => {
    // 2024-02-01 is a Thursday, so the 29th is the fifth Thursday: cell 3 + 28.
    const grid = getCalendarLayout(new Date(2024, 1, 1), false);
    const flat = cells(grid);

    assert.equal(flat[31].day, "29");
    assert.equal(flat[31].today, 0);
    assert.equal(flat[32].day, "1");
    assert.equal(flat[32].today, -1);
});

test("today is marked only in the month actually being viewed", () => {
    const today = new Date();
    const thisMonth = getCalendarLayout(new Date(today.getFullYear(), today.getMonth(), 1), true);
    const marked = cells(thisMonth).filter(cell => cell.today === 1);

    assert.equal(marked.length, 1);
    assert.equal(marked[0].day, String(today.getDate()));

    // Navigating away must not mark a neighbouring month's same-numbered day.
    const nextMonth = getCalendarLayout(new Date(today.getFullYear(), today.getMonth() + 1, 1), false);
    assert.equal(cells(nextMonth).filter(cell => cell.today === 1).length, 0);
});

test("the month shift walks whole months from the current one", () => {
    const now = new Date();

    assert.equal(getDateInXMonthsTime(0).getMonth(), now.getMonth());
    assert.equal(getDateInXMonthsTime(0).getDate(), 1);
    assert.equal(getDateInXMonthsTime(12).getFullYear(), now.getFullYear() + 1);
    assert.equal(getDateInXMonthsTime(-12).getFullYear(), now.getFullYear() - 1);
});
