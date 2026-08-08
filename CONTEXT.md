# Context

Glossary for this shell. Terms only — no implementation detail, no decisions.
Decisions live in their issue; structure lives in the code.

## Dashboard

**Dashboard** — The shell surface opened from the bar clock that contains selectable
destinations.

**Destination** — A selectable view within the Dashboard, with a stable identity distinct
from its presentation label.

**Dashboard destination** — The date-and-weather overview labelled “Dashboard”. Use the full
term when it could be confused with the Dashboard surface.
_Avoid_: Calendar destination

**Performance destination** — The Dashboard view for current and recent CPU, memory,
network, and root-storage behavior.

**Warning state** — A presentational state indicating that a current resource reading has
crossed its metric-specific threshold. It clears when the current reading recovers and does
not describe historical samples.
_Avoid_: Pressure

**Pane** — The live presentation of a destination inside the Dashboard. A destination keeps
its identity when its pane is absent and receives a new pane when revisited.

**Track segment** — The permanent region of the Dashboard's transition track belonging to one
destination. It exists whether or not that destination's pane is present.

**Rest geometry** — The Dashboard's arrangement after transition motion has settled. It is
independent of whether the selected destination's data is complete.

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

**Stride** — the distance from one slot's left edge to the next one's, in pixels. It is a
constant, so every position in the row is arithmetic from it rather than read back off a
laid-out item.

**Urgent** — a workspace flagged by the compositor as demanding attention. A property of
the workspace, not of the windows in it.

**Special** — Hyprland's overlay workspace, addressed by name rather than number.
It is never a slot: it has no ordinal position, and its numeric id is allocated
dynamically and is not stable between sessions. At most one special is visible per
monitor.

**Scratchpad** — a named special used to park one window (here, `special:quake`).
A scratchpad is a special; not every special is a scratchpad.

**Visible** (of a special) — currently drawn over its monitor. Distinct from
*existing*: a special that holds windows exists whether or not it is showing, so
visibility is not derivable from the workspace list.
