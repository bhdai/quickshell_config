import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { retain, persistable, RETENTION_MS, HISTORY_LIMIT } = loadQmlJs(
    new URL("../services/notification_retention.js", import.meta.url),
    ["retain", "persistable", "RETENTION_MS", "HISTORY_LIMIT"],
);

const now = 1_800_000_000_000;
const hour = 60 * 60 * 1000;

test("history keeps the last day", () => {
    const fresh = { time: now - 23 * hour };
    const stale = { time: now - 25 * hour };
    assert.deepEqual(retain([fresh, stale], now), [fresh]);
});

test("an entry exactly at the cutoff has expired", () => {
    assert.deepEqual(retain([{ time: now - RETENTION_MS }], now), []);
});

test("history keeps the newest entries once it is over the limit", () => {
    const entries = Array.from({ length: HISTORY_LIMIT + 5 }, (_, i) => ({ time: now - i }));
    const kept = retain(entries, now);
    assert.equal(kept.length, HISTORY_LIMIT);
    assert.equal(kept[0], entries[0]);
    assert.equal(kept.at(-1), entries[HISTORY_LIMIT - 1]);
});

test("transient notifications are never written to disk", () => {
    const kept = { time: now, isTransient: false };
    assert.deepEqual(persistable([kept, { time: now, isTransient: true }]), [kept]);
});
