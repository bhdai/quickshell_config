.pragma library

// Every entry is somebody's message, so history keeps only the recent past: whichever of the
// age and the count limit bites first. Without a bound the list only grows, and a list nobody
// can get to the bottom of stops being read.
const RETENTION_MS = 24 * 60 * 60 * 1000;
const HISTORY_LIMIT = 100;

// `entries` is newest first, each with `time` in milliseconds since the epoch.
function retain(entries, now) {
    const cutoff = now - RETENTION_MS;
    return entries.filter(entry => entry.time > cutoff).slice(0, HISTORY_LIMIT);
}

// A notification carrying the `transient` hint asks to skip persistence: it matters while it is
// on screen, and its sender sends it again if it still applies.
function persistable(entries) {
    return entries.filter(entry => !entry.isTransient);
}
