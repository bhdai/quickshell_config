# Context

Glossary for this shell. Terms only — no implementation detail, no decisions.
Decisions live in their issue; structure lives in the code.

## Workspaces

**Workspace** — Hyprland's object, as Quickshell exposes it via
`Quickshell.Hyprland`. It exists only while something references it, so the set of
workspaces is smaller than the set of numbers a user can reach.

**Slot** — an ordinal position in the workspace indicator, numbered from 1. Slots
are contiguous and always present; a slot exists whether or not a workspace with
that number does. The distinction from *workspace* is load-bearing: a slot with no
workspace behind it is the normal case, not an error.

**Dot** — the circle drawn for a slot. One dot per slot. A dot's size and colour
say whether its workspace exists and holds windows; the dot is presentation, the
slot is position.

**Occupied** — a slot whose workspace exists and holds at least one window. Not the
same as *existing*: Hyprland keeps an empty workspace alive while it is focused.

**Special** — Hyprland's overlay workspace, addressed by name rather than number.
It is never a slot: it has no ordinal position, and its numeric id is allocated
dynamically and is not stable between sessions. At most one special is visible per
monitor.

**Scratchpad** — a named special used to park one window (here, `special:quake`).
A scratchpad is a special; not every special is a scratchpad.

**Visible** (of a special) — currently drawn over its monitor. Distinct from
*existing*: a special that holds windows exists whether or not it is showing, so
visibility is not derivable from the workspace list.
