# Special / scratchpad workspaces in bar workspace widgets

Research performed on 2026-08-05 for issue #118 (part of the #116 workspace-indicator
rewrite map). Primary sources, in order of authority:

- **end-4 `dots-hyprland`** at `/home/dai/ghq/github.com/end-4/dots-hyprland`,
  commit `aed4d1e` — read in full.
- **DankMaterialShell** at `/home/dai/ghq/github.com/AvengeMedia/DankMaterialShell`,
  commit `6ad46cf` — read in full for every `special` occurrence in the repo.
- **Hyprland 0.56.1 source** (`hyprwm/Hyprland` tag `v0.56.1`) for the workspace-id
  allocation rules.
- **Quickshell 0.3.0 docs** at `quickshell.org/docs/v0.3.0` plus the installed
  `quickshell 0.3.0` binary, driven by a throwaway probe config against the live
  Hyprland session.

## Evidence labels

Used throughout. The distinction is load-bearing because nobody on this ticket can see
either shell running.

- **Source** — read from the named file at the named commit. Determines behaviour.
- **Measured** — observed by running a probe against this machine's live Hyprland
  0.56.1 / Quickshell 0.3.0. Reproducible.
- **Docs** — stated on quickshell.org for v0.3.0.
- **Inference** — follows from the above. The appearance claims are all inference:
  the code fixes geometry, colour and opacity, so shape is derivable, but nothing
  here was seen rendered.

---

## Executive answer

The two references sit at opposite extremes, and **neither is directly reusable** for a
constant-stride dot row.

| | end-4 | Dank |
|---|---|---|
| Special shown in bar? | Yes — as a **full-row takeover overlay** | **No.** Filtered out entirely |
| Horizontal cost | 0 px added; overlay can *overflow* the widget | 0 px |
| Code cost | ~45 lines across 2 files, needs 4 custom effect widgets | 5 lines (one `filter` predicate) |
| Multiple named specials | Displays whichever is visible; **dismiss is hardcoded to one** | n/a |
| Data source | `hyprctl monitors -j` subprocess | `HyprlandMonitor.lastIpcObject` + `activespecial` event |

end-4's treatment is the only real *design* in the two repos, and its core idea —
**zero horizontal cost, because the special state is expressed by transforming the
row rather than extending it** — is the transferable part. Its execution (blur the
whole row, cover it with a text pill) is the part that fights a 40 px bar and a
constant-stride model.

Dank surfaces specials nowhere in the bar. Its special-workspace machinery exists
solely so the **dock** can decide whether to auto-hide, and its bar filter is the
minimal defensive one.

The most important finding is not in either repo: **Quickshell 0.3.0 has no native
special-workspace API on `HyprlandMonitor`**, but there is a much cheaper route than
end-4's `hyprctl` subprocess — the `activespecial` raw event, which carries name and
monitor directly. See §4.

---

## 1. end-4: the `specialBlur` mechanism

### 1.1 What is actually drawn

Source: `dots/.config/quickshell/ii/modules/ii/bar/Workspaces.qml`.

The whole widget is a `ButtonMouseArea` (`:14`) whose only sizing input is the regular
workspace row: `implicitWidth: occupiedIndicators.implicitWidth` (`:40`). Everything
special-related is layered *over* that, and none of it feeds implicit size.

A single driving scalar, `specialBlur`, ramps 0 → 1 (`:43-46`):

```qml
property real specialBlur: (wsModel.specialWorkspaceActive && !containsMouse) ? 1 : 0
Behavior on specialBlur {
    animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
}
```

`elementMoveSmall` is 350 ms on the `expressiveFastSpatial` bezier
(`modules/common/Appearance.qml:252,264,285-297`) — a springy overshoot curve, the same
family this repo already has as `Appearance.animation.expressiveFastSpatial`.

Three things read that scalar.

**(a) The regular row recedes.** `Item { id: regularWorkspaces }` wraps every regular
element — occupied pills, active indicator, hover overlay, numbers, app icons — and at
`:84-92`:

```qml
scale: 1 - 0.08 * root.specialBlur       // 1.00 → 0.92
layer.enabled: root.specialBlur > 0
layer.effect: MultiEffect {
    brightness: -0.1 * root.specialBlur  // 10% darker
    blurEnabled: true
    blur: root.specialBlur
    blurMax: 32                          // up to a 32 px gaussian radius
}
```

So at full effect the row is at 92 % scale, 10 % darker, and blurred with a 32 px max
radius. **Inference:** at 26 px buttons a 32 px blur radius is larger than the elements
being blurred, so the row becomes an unreadable coloured smear — legibility is not the
goal; it is deliberately reduced to a backdrop.

**(b) A pill fades in over the centre.** `:286-320`:

```qml
FadeLoader {
    anchors.centerIn: parent
    shown: wsModel.specialWorkspaceActive
    scale: 0.8 + 0.2 * root.specialBlur   // 0.8 → 1.0
    opacity: root.specialBlur
    Behavior on opacity {}                // deliberately empty; specialBlur is already animated

    sourceComponent: Pill {
        anchors.centerIn: parent
        property real undirectionalWidth: root.activeWorkspaceSize        // 22
        property real undirectionalLength: specialWsText.implicitWidth + undirectionalWidth
        color: Appearance.colors.colPrimary
        StyledText {
            id: specialWsText
            anchors.centerIn: parent
            text: (!root.vertical ? wsModel.specialWorkspaceName : "S")
            color: Appearance.colors.colOnPrimary
            font.pixelSize: root.specialTextSize                          // 13
        }
    }
}
```

`Pill` is one line — `Rectangle { radius: Math.min(width, height) / 2 }`
(`modules/common/widgets/Pill.qml`) — so this is a fully-rounded stadium, 22 px tall,
`textWidth + 22` wide, filled `colPrimary` with `colOnPrimary` 13 px text. **Inference:**
it reads as the same object as the active-workspace pill (same `colPrimary` fill, same
22 px `activeWorkspaceSize` height as the active indicator at `:429`), grown sideways
and given a word instead of a number.

**(c) Everything else is unchanged.** There is no badge, no icon, no border, no second
indicator. Searching the whole `ii` config for `special` returns hits only in
`Workspaces.qml` and `WorkspaceModel.qml` (plus one unrelated `SysTrayMenu` identifier).
The overview, the dock equivalent and the sidebars have no special-workspace treatment.

### 1.2 Geometry, concretely

Constants at `:26-34`, with end-4's `baseBarHeight: 40` (`Appearance.qml:388`) — the
same bar height this repo uses (`modules/bar/Bar.qml:54`), so these numbers transfer
without scaling:

| Token | Value |
|---|---|
| `workspaceButtonWidth` | 26 (constant stride — end-4 is already constant-stride) |
| `activeWorkspaceMargin` | 2 |
| `activeWorkspaceSize` | 22 (`26 − 2×2`) |
| `specialTextSize` | 13 (`26 × 0.5`) |
| `Config.options.bar.workspaces.shown` | 10 (`modules/common/Config.qml:263`) |

Row width at the default = `10 × 26 = 260 px`. The special pill's width is
`textWidth + 22`; for `"quake"` at 13 px that is **inference** roughly 38 + 22 ≈ 60 px,
comfortably inside 260.

**The pill does not participate in `implicitWidth`.** Root implicit width is bound to
`occupiedIndicators.implicitWidth` (`:40`) and the `FadeLoader` is a sibling anchored
`centerIn: parent`. **Inference:** with a short row (the code's own comment at `:298`
worries about a 2-workspace config) or a long special name, the pill silently overflows
the widget's reported bounds and overlaps its neighbours in the bar. The vertical
variant dodges this by drawing a literal `"S"` instead of the name (`:311`).

**Horizontal cost: zero.** This is the treatment's whole point, and the reason it is
worth borrowing from at all.

### 1.3 How the name is surfaced

Source: `modules/common/models/WorkspaceModel.qml:11,18-20`:

```qml
readonly property var liveMonitorData: HyprlandData.monitors.find(m => m.id === monitor.id)
readonly property var specialWorkspace: liveMonitorData?.specialWorkspace
readonly property string specialWorkspaceName: specialWorkspace?.name.replace("special:", "") ?? "special"
readonly property bool specialWorkspaceActive: specialWorkspaceName !== ""
```

Two subtleties worth stating because they look like bugs and are not:

- `?? "special"` only fires when `liveMonitorData` itself is missing (JS optional
  chaining short-circuits the whole `?.name.replace(...)` chain). It is a *fallback for
  no monitor data*, not the empty-name case.
- The empty-name case works because **`hyprctl monitors -j` always emits a
  `specialWorkspace` object**, `{"id": 0, "name": ""}` when none is visible.
  *Measured* on this machine: `eDP-1 {"id": 0, "name": ""}` with nothing toggled, and
  `{"id": -98, "name": "special:quake"}` with `special:quake` shown. So
  `"".replace(...) !== ""` is false and `specialWorkspaceActive` is correctly false.

`HyprlandData` is end-4's own singleton, documented in its own header as *"Provides
access to some Hyprland data not available in Quickshell.Hyprland"*
(`services/HyprlandData.qml:10-12`). It gets monitors by spawning
`["hyprctl", "monitors", "-j"]` (`:114-123`) — see §4 for why that matters.

### 1.4 How it is dismissed — and the multiple-specials limit

Three interactions touch it.

**Peek by hover.** `specialBlur` is gated on `&& !containsMouse` (`:43`). Moving the
pointer onto the widget drives it back to 0 — the row un-blurs and the special pill
fades out, over the same 350 ms curve. **Inference:** this reads as "lean in to see
what's underneath"; it does *not* change compositor state, and moving away restores the
special view.

**Toggle by back-button.** `:69-71` → `:60-62`:

```qml
function toggleSpecial() {
    Hyprland.dispatch(`hl.dsp.workspace.toggle_special("special")`);
}
```

Bound to `Qt.BackButton` (mouse button 4). **This is the multiple-specials failure.**
The dispatch argument is the literal string `"special"`, not `wsModel.specialWorkspaceName`.
With `special:quake` showing, back-button does not dismiss it — it toggles the *unnamed*
`special` on instead, which (Hyprland allows one special per monitor) replaces quake.
Pressing it again then hides `special`, leaving quake also hidden. **Inference:** the
observable result for a two-special user is that dismissal takes two clicks and passes
through a wrong intermediate state.

**Left-click.** Falls through to `switchWorkspaceToHovered()` (`:64-66`), which focuses
the regular workspace under the cursor — computed from `Math.floor(mouseX / 26)`
(`:51-54`), i.e. from the *blurred, invisible* row beneath the pill. **Inference:** the
pill is a click target for a workspace you cannot currently see.

**Summary on multiplicity:** end-4 *displays* whichever special is visible correctly
(the name comes from the monitor), but *acts* as if there is exactly one, and that one
is named `special`.

### 1.5 Code cost

| Piece | Lines | Where |
|---|---|---|
| `specialBlur` scalar + Behavior | 4 | `Workspaces.qml:43-46` |
| `toggleSpecial()` + back-button wiring | 5 | `:60-62,69-70` |
| Row scale + layer + `MultiEffect` | 9 | `:84-92` |
| The overlay `FadeLoader` + `Pill` | 35 | `:286-320` |
| Model plumbing | 4 | `WorkspaceModel.qml:11,18-20` |
| **Total** | **~57** | |

Plus dependencies this repo does **not** have: `FadeLoader`, `Pill`, `StyledText`
(this repo has `StyledText`), and a working `layer.effect: MultiEffect` over a live
subtree. The last one is the real cost — per the project memory note
`offscreen-grab-drops-masked-content`, layered/masked content in this repo does not
survive offscreen grabs, so a `MultiEffect` treatment **cannot be verified by the
fixture harness** and would have to be judged live by eye.

---

## 2. Dank: specials are filtered out

### 2.1 The bar

Source: `quickshell/Modules/DankBar/Widgets/WorkspaceSwitcher.qml`. The entire
special-workspace surface of this 2136-line file is five lines, `:267-274`:

```qml
// Hyprland gives named workspaces negative ids (from -1337 down); special
// workspaces always store a "special:" name prefix ("special" pre-colon era)
let filtered = workspaces.filter(ws => {
    if (ws.id > 0)
        return true;
    const name = ws.name ?? "";
    return name !== "special" && !name.startsWith("special:");
});
```

Note the predicate is *not* `id > 0`. Dank deliberately **keeps** negative-id workspaces
that are merely *named* (Hyprland's `name:` workspaces, ids from −1337 down) and puts
them after the numbered ones via `hyprlandWorkspaceOrder` (`:241-248`). Only `special:*`
is dropped. There is no `else` branch, no badge, no alternate row, nothing.

Grepping the whole repository for `special` confirms this is the only bar-side handling.
The remaining hits are: the keybind editor's label for the `togglespecialworkspace`
dispatcher (`quickshell/Common/KeybindActions.js:377,579`,
`core/internal/keybinds/providers/hyprland.go:889-893`), the dock, and unrelated
identifiers.

### 2.2 Where Dank *does* track specials — the dock, not the bar

Source: `quickshell/Services/CompositorService.qml`.

`property var hyprlandVisibleSpecialWorkspaces: ({})` (`:42`) is a map
`monitorName → "special:<name>"`, rebuilt by `updateHyprlandVisibleSpecialWorkspaces()`
(`:297-331`) on the `activespecial` raw event (`:185-194`) and at startup (`:213`).

Its only consumers are two dock-overlap functions (`:556-582`, `:760-766`) that decide
whether a window on a *visible* special overlaps the dock, for smart auto-hide
(`quickshell/Modules/Dock/DockBody.qml:295`). The dock also has a per-window
"bring the special workspace back before focusing" action
(`quickshell/Modules/Dock/DockAppButton.qml:149-170`), gated behind a setting described
in `quickshell/Modules/Settings/DockTab.qml:179-181`.

Two details from this code are worth stealing regardless of the chosen form:

**Name normalisation** (`:264-271`) — the unnamed special is canonicalised to
`"special:special"`:

```qml
if (raw === "special") return "special:special";
return raw.startsWith("special:") ? raw : `special:${raw}`;
```

**Defensive property probing** (`:285-295`) — Dank tries five candidate paths for the
name, in order:

```qml
const candidates = [monitor.activeSpecialWorkspace?.name, monitor.specialWorkspace?.name,
                    monitor.lastIpcObject?.specialWorkspace?.name, monitor.lastIpcObject?.specialWorkspace,
                    monitor.lastIpcObject?.activeSpecialWorkspace?.name];
```

**Inference:** this list is Dank hedging across Quickshell versions. On Quickshell 0.3.0
only the third one is ever non-null — see §4, where the first two were *measured* as
`undefined`.

**Multiplicity:** the map is keyed by monitor, so Dank tracks one visible special *per
monitor* and any number across monitors. That is exactly Hyprland's own constraint, so
Dank is not limited here — but it never renders any of it in the bar, so the question is
moot for our purposes.

### 2.3 Cost

Horizontal: **zero**. Code: **five lines**, and they are lines the rewrite needs anyway
— the map (#116) already calls for explicit `id >= 1` filtering, which subsumes Dank's
predicate for our case (we have no `name:` workspaces).

Dank's pill row is also **not** constant-stride, so its geometry does not transfer:
inactive pill width is `max(widgetHeight × 0.7, appIconSize × 1.2)`, active is
`max(widgetHeight × 1.05, appIconSize × 1.6)` (`:1245`) — i.e. the active pill is
~50 % wider than the others, at `widgetHeight: 30` (`:18`) roughly 31.5 px vs 21 px,
gap `Theme.spacingS` = 8 (`quickshell/Common/Theme.qml:997`). Ruled out by #116 already.

---

## 3. Hyprland's own model of specials (verified)

Everything in this section was **measured** on this machine (Hyprland 0.56.1,
`5c9377c`) or read from the tagged Hyprland source, because the design depends on it and
the two shells' comments disagree in the details.

### 3.1 Id allocation

Source: `src/macros.hpp:22` — `#define SPECIAL_WORKSPACE_START (-99)`.
Source: `src/state/WorkspaceQueryCore.cpp:70-81`:

```cpp
WORKSPACEID CWorkspaceQueryCore::newSpecialID(...) {
    WORKSPACEID highest = SPECIAL_WORKSPACE_START;
    for (const auto& ws : workspaces) { if (ws.special && ws.id > highest) highest = ws.id; }
    return highest + 1;
}
```

and `:83-95`, named (non-special) workspaces start from `-1337 + 1` and go **down**.

So the two negative ranges are disjoint and in opposite directions:

| Kind | Id range | Direction |
|---|---|---|
| Special / scratchpad | −99 upward (−98, −97, …) | grows toward 0 |
| Named (`name:foo`) | −1337 downward | grows away from 0 |

**Measured:** with nothing else present, `special:quake` was allocated **−98**, and a
subsequently-created unnamed special (while quake still existed) got **−97**, *not* −99.
**Ids are dynamically allocated and are not stable across sessions or across the order
you happen to open your scratchpads in.** Key any UI on the **name**, never the id.

Source: `src/helpers/MiscFunctions.cpp:125-140` — the unnamed special is stored with the
name `"special:special"`. Both reference shells' string handling agrees with this.

### 3.2 One visible special per monitor

**Measured:** `hyprctl monitors -j` exposes `specialWorkspace` as a **single object**,
not a list — `{"id": 0, "name": ""}` when none is visible. Showing a second special
replaces the first. This is a hard compositor constraint, not a shell choice:
**an indicator never needs to display more than one special at a time per monitor.**

The user's two specials (`special` via `SUPER+s`, and `special:quake`) are therefore
mutually exclusive on screen. What varies is *which one*, which is why the element must
be able to say *which*, and why end-4's hardcoded `toggle_special("special")` is wrong.

### 3.3 Exists ≠ visible

**Measured**, and this is the trap:

- An empty special workspace does not persist. Toggling `special:quake` on with no
  windows in it creates workspace −98; toggling it off destroys it again.
- A special **with** windows persists in `Hyprland.workspaces` whether or not it is
  showing.
- `HyprlandWorkspace.active` and `.focused` are **`false` on the special even while it
  is visible on the monitor** — measured twice. The regular workspace underneath keeps
  `active: true`.

So there are three distinguishable states, and they are three different design
questions:

| State | Detect via |
|---|---|
| Scratchpad does not exist | absent from `Hyprland.workspaces` |
| Exists, hidden (has windows, stashed) | present in `Hyprland.workspaces`, name `special:*`, but not the monitor's visible special |
| Exists, visible | monitor's `specialWorkspace.name` non-empty / last `activespecial` for this monitor non-empty |

end-4 draws only the third. **Inference:** a "you have 2 windows stashed" affordance is
possible and neither reference implements it — `HyprlandWorkspace.toplevels`
(*Docs*: "List of toplevels on this workspace") gives the count for free.

---

## 4. What Quickshell 0.3.0 actually exposes

The ticket's suspicion is correct, and the consequence is better than feared.

### 4.1 There is no native property

*Docs* (`quickshell.org/docs/v0.3.0/types/Quickshell.Hyprland/HyprlandMonitor`):
`HyprlandMonitor` has `id, name, description, x, y, width, height, scale, focused,
activeWorkspace, lastIpcObject`. **No `specialWorkspace`, no `activeSpecialWorkspace`.**

*Docs* (`.../HyprlandWorkspace`): `id, name, active, focused, urgent, monitor,
hasFullscreen, toplevels, lastIpcObject`, plus `activate()`. **No `special` flag.**

**Measured** against the installed 0.3.0 binary — `monitor.specialWorkspace` and
`monitor.activeSpecialWorkspace` both evaluate to `undefined`, while
`monitor.lastIpcObject.specialWorkspace` yields the real object. This is also why Dank
probes five paths (§2.2): only the `lastIpcObject` one works here.

### 4.2 `lastIpcObject` is stale by design

*Docs*: "This is *not* updated unless the monitor object is fetched again from Hyprland.
If you need a value that is subject to change and does not have a dedicated property,
run `Hyprland.refreshMonitors()` and wait for this property to update."

**Measured:** at the instant the `activespecial` event fires,
`lastIpcObject.specialWorkspace` still reads `{"id":0,"name":""}`. After calling
`Hyprland.refreshMonitors()` it had updated within 250 ms. `Qt.callLater` was **not**
long enough — the refresh is a socket round-trip.

### 4.3 The cheap route end-4 missed: the `activespecial` raw event

**Measured** — `Hyprland.rawEvent` delivers both of these on every show and hide:

| Event | `data` on show | `data` on hide | `parse(n)` |
|---|---|---|---|
| `activespecial` | `"special:quake,eDP-1"` | `",eDP-1"` | `parse(2)` → `["special:quake","eDP-1"]` |
| `activespecialv2` | `"-98,special:quake,eDP-1"` | `",,eDP-1"` | needs `parse(3)`; `parse(2)` mis-splits |

Empty name means hidden. The monitor name is the second (v1) field, so this is
**per-monitor for free** — which the rewrite needs anyway, since #116 puts one bar per
screen via `Variants`.

**This removes the need for `hyprctl monitors -j` entirely.** end-4 pays a heavy price
for that subprocess: `HyprlandData.qml:86-94` re-runs *five* `hyprctl` processes on
essentially every Hyprland event. The rewrite can hold a single string property fed by
`activespecial` and never spawn anything.

Two caveats, both measured:

- **Startup.** In `Component.onCompleted`, `Hyprland.workspaces` was **empty** and
  `Hyprland.focusedMonitor` was **null**; both were populated by 1200 ms.
  A special already visible at shell start emits no event, so the initial value must
  come from `refreshMonitors()` + `lastIpcObject`, exactly as Dank does at
  `CompositorService.qml:213`. *(This is also a data point for #117 — the async
  population at `Component.onCompleted` is real and observable.)*
- **The special lingers in the model after hiding.** Measured: at the instant of the
  hide event, workspace −98 was still in `Hyprland.workspaces`; it was gone 250 ms
  later. So visibility must **never** be derived from model membership.

### 4.4 Sort order bites

*Docs*: `Hyprland.workspaces` is "All hyprland workspaces, sorted by id", and "Named
workspaces have a negative id, and will appear before unnamed workspaces". **Measured:**
with quake visible the model read
`[{-98 special:quake}, {1}, {2}, {3}]` — the special is **first**, ahead of workspace 1.
Any code that indexes `Hyprland.workspaces.values` positionally, rather than filtering on
`id >= 1` first, is wrong whenever a scratchpad has windows. #116 already mandates the
explicit filter; this is the concrete failure it prevents.

### 4.5 Dispatch syntax on this machine

**Measured:** this Hyprland is in **Lua config mode**. `hyprctl dispatch
togglespecialworkspace quake` fails with a Lua parse error; the working form is
`hl.dsp.workspace.toggle_special("quake")` — which is precisely what end-4
(`Workspaces.qml:61`) and Dank (`HyprlandService.qml:608-612`) emit. Dank branches on
the mode; end-4 assumes Lua. Any click-to-toggle affordance we build must use the Lua
form, or branch on `Hyprland.usingLua` (*Docs*: the singleton exposes it).

---

## 5. Candidate forms for the separate element

The map has settled that this is a **separate element, not a dot in the ordinal row**.
The forms below are drawable from this section alone. All measurements are in the
current widget's tokens (`modules/bar/WorkspaceIndicator.qml:13-21`:
`itemContainerWidth` 24, `pillSpacing` 5 → **stride 29**, `activeSize` 20,
`horizontalPadding` 8) inside a **40 px** bar (`modules/bar/Bar.qml:54`).

Every form needs the same three inputs, all now available without a subprocess:
`visibleSpecialName` (string, `""` when none), `stashedSpecialNames` (names present in
`Hyprland.workspaces` matching `special:*`), and `windowCount` per special
(`HyprlandWorkspace.toplevels.values.length`).

### Form A — end-4 verbatim: blur-and-overlay

Regular row scales to 0.92, darkens 10 %, blurs (32 px max radius); a `colPrimary`
stadium, height = `activeSize` (20), width = `textWidth + 20`, fades in centred over
it with `colOnPrimary` text at 13 px. Hover un-blurs to peek.

- **Horizontal cost: 0 px** (but overflows bounds if the name is long — end-4's own
  vertical variant substitutes a literal `"S"` to dodge this).
- **Code: ~57 lines**, plus a live `MultiEffect` over a layered subtree.
- **Risk specific to this repo:** the memory note `offscreen-grab-drops-masked-content`
  means a `MultiEffect`-based treatment cannot be checked by the fixture harness. Every
  iteration would need the user's eyes.
- Says nothing about a *stashed* scratchpad, only a visible one.

### Form B — Dank verbatim: nothing

Filter `id >= 1` and stop.

- **Cost: 0 px, 0 lines beyond the filter #116 already mandates.**
- The baseline every other form must beat. Worth keeping honest about: the user said the
  feature is "interesting", not that it is needed.

### Form C — trailing chip, appears on demand

A separate stadium after the dot row, separated by more than one stride so it reads as
"not part of the sequence" — e.g. a `2 × pillSpacing` gap (10 px). Height = `activeSize`
(20), fully rounded. Contents: a `MaterialSymbol` (this repo has one) — Material's
`filter_drama`, `layers`, or `bolt` for a scratchpad — plus, optionally, the stripped
name when visible.

- **Horizontal cost: +30 px** for an icon-only 20 px chip plus the 10 px gap;
  **+30 + textWidth** if it carries the name. This is the honest cost, and it is
  the widget *growing*, which fights the "make it smaller" goal of #116 — unless it is
  only present when a special exists.
- **Animate the same way as dot growth.** #116 already specifies `implicitWidth` animates
  on `expressiveFastSpatial`; the chip appearing is the same transition.
- Naturally expresses all three states: absent (chip not there), stashed (chip outlined /
  `colSurfaceVariant`), visible (chip filled `colPrimary`). Distinguishing the two
  specials is a label or a second chip.
- Click target is unambiguous, unlike Form A.

### Form D — leading gutter glyph, fixed slot

Same chip, placed **before** the dot row instead of after, in a permanently-reserved
slot that is empty when no special exists.

- **Horizontal cost: +30 px, always** — the slot is reserved so the dot row never shifts.
  Costs more than C in the common case, buys a row that never moves horizontally.
- **Inference:** with the bar order `[distro logo] [workspaces] [active window]`, a
  leading element sits directly against the distro logo and may read as part of it.
  C's trailing position abuts the active-window text instead.

### Form E — badge on the widget's own background

No new element in the flow. The widget already has a `WrapperRectangle` background
(`WorkspaceIndicator.qml:69-75`, `colLayer1`, radius 20, margin 5). When a special is
visible, restyle *that*: swap the fill toward `colSecondaryContainer`, or draw a 2 px
`colPrimary` outline, or a small filled circle overlapping the top-right corner.

- **Horizontal cost: 0 px.** Same virtue as A without any blur.
- **Code: ~10 lines** — a colour binding with a `ColorAnimation`, or one extra
  `Rectangle`.
- **Cannot say *which* special.** For a user with exactly two, this reduces to "a
  scratchpad is up" — which may be all that is wanted, since they know which key they
  pressed.
- Composable: E for "something is up" + a tooltip or click-to-cycle for "which".

### Form F — active-pill annotation

Leave the row alone, but mark the *active pill* while a special covers it: shrink it to
a ring, dim it to `colOnLayer1Inactive`, or slide it down a few px. Signals "the
workspace you are looking at is not the one this pill points to".

- **Horizontal cost: 0 px. Code: ~5 lines.**
- Cheapest non-zero option, and it is honest about what changed: the visible content, not
  the workspace.
- **Inference:** likely too subtle at a 20 px pill to be noticed without being told.
  Says nothing about which special.

### Comparison

| | Horiz. cost | Code | Says *which* special | Shows stashed | Fixture-verifiable |
|---|---|---|---|---|---|
| A end-4 blur | 0 (can overflow) | ~57 + MultiEffect | yes | no | **no** |
| B Dank nothing | 0 | 0 | — | — | yes |
| C trailing chip | +30, only when present | ~25 | yes | yes | yes |
| D leading slot | +30 always | ~25 | yes | yes | yes |
| E background badge | 0 | ~10 | no | possible | partly (colour, not blur) |
| F pill annotation | 0 | ~5 | no | no | yes |

### What the evidence points at

Not a decision — the bake-off ticket owns that — but the constraints do narrow it:

- **A is the one to be most careful about.** It is the only treatment either reference
  actually designed, and its zero-cost idea is genuinely good, but it depends on a
  `MultiEffect` this repo cannot verify offscreen, and end-4's own dismissal logic
  breaks on the exact two-special configuration the user has.
- **C and E are the two that survive the constraints.** C pays 30 px to be unambiguous;
  E pays nothing and is ambiguous between the user's two specials. They compose.
- **Every form is cheap on the data side now.** The `activespecial` event (§4.3) makes
  the state a single string property with no subprocess, so the choice is purely visual
  — which is what the prototype is for.

---

## Sources

**Read at commit:**

- `end-4/dots-hyprland@aed4d1e` — `dots/.config/quickshell/ii/modules/ii/bar/Workspaces.qml`,
  `.../modules/common/models/WorkspaceModel.qml`, `.../modules/common/widgets/{Pill,FadeLoader,ButtonMouseArea}.qml`,
  `.../modules/common/{Appearance,Config}.qml`, `.../services/HyprlandData.qml`.
- `AvengeMedia/DankMaterialShell@6ad46cf` — `quickshell/Modules/DankBar/Widgets/WorkspaceSwitcher.qml`,
  `quickshell/Services/{CompositorService,HyprlandService}.qml`,
  `quickshell/Modules/Dock/{DockBody,DockAppButton}.qml`, `quickshell/Common/Theme.qml`.
- `hyprwm/Hyprland@v0.56.1` — `src/macros.hpp`, `src/helpers/MiscFunctions.cpp`,
  `src/state/WorkspaceQueryCore.cpp`.

**Docs:** `https://quickshell.org/docs/v0.3.0/types/Quickshell.Hyprland/{Hyprland,HyprlandMonitor,HyprlandWorkspace}`.

**Measured:** Hyprland 0.56.1 (`5c9377c`), Quickshell 0.3.0 (Arch), single monitor
`eDP-1`. Probe: a throwaway `ShellRoot` run via `qs -p`, logging
`Hyprland.workspaces.values`, `focusedMonitor.lastIpcObject.specialWorkspace` and every
`activespecial` / `activespecialv2` raw event while `special:quake` was toggled on and
off. Session state was restored (`specialWorkspace` back to `{"id": 0, "name": ""}`).
