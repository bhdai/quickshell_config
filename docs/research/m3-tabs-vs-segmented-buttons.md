# Material 3: tabs vs segmented buttons for a two-destination popup

Research performed on 2026-07-30 against `m3.material.io` (the live Material Design 3
spec) and the first-party Jetpack Compose Material 3 implementation. Motivating case: a
fixed 700×507 popup card with a 48 px control at the top that switches the pane below
between exactly two destinations, "Calendar" and "Wallpaper".

## Executive answer

The spec points at **tabs**, specifically **primary tabs**, not segmented buttons.

- Tabs are the component M3 defines for *content destinations* switched by a control that
  sits above the region it controls. Primary tabs "display the main content destinations"
  and are the variant to use "when just one set of tabs are needed".
- Segmented buttons are not disqualified by their stated purpose — M3's own one-line
  definition includes "switch views" — but they are a **selection** control whose spec
  forbids the layout this case needs: a segmented button must not span the full width of
  a pane, and it has no divider, no destination semantics, and no notion of a controlled
  region below it. It is also **no longer recommended** as of the M3 Expressive update
  (May 2025).
- M3 sets a *maximum* of four tabs and no minimum. It explicitly recommends tabs over a
  navigation bar when there are fewer than three destinations, which is direct support
  for a two-tab set.
- M3 states in one sentence that tabs may be "nested within components like cards and
  sheets", but gives **no** measurements, variants, or guidance specific to a popup,
  menu, or small container. Everything below that sentence is silence, not guidance.
- The 48 px control height in the case at hand is exactly the M3 label-only tab container
  height (48dp).

## Evidence labels

- **Spec** — stated on an `m3.material.io` page; URL cited.
- **Verified in source** — read from the first-party androidx Compose Material 3 source
  on `androidx-main`, which is where the Material design tokens are published as code.
- **Silence** — the spec was checked for the claim and does not address it.
- **Inference** — follows from the cited facts; the spec does not say it.

---

## 1. Which component does M3 say this is?

### What each component is defined as

| | One-line definition | Source |
|---|---|---|
| Tabs | "Tabs organize content across different screens and views" | [Tabs: Overview](https://m3.material.io/components/tabs/overview) |
| Segmented buttons | "Segmented buttons help people select options, switch views, or sort elements" | [Segmented buttons: Overview](https://m3.material.io/components/segmented-buttons/overview) |
| Connected button group | "help people select options, switch views, or sort elements in a page" | [Button groups: Guidelines](https://m3.material.io/components/button-groups/guidelines) |

**The premise in the question is only half right.** M3 does *not* say segmented buttons
are for filtering only and never for view switching — "switch views" is in the component's
own subtitle, repeated on the Overview, Guidelines, and single-select sections, and the
Guidelines say to use a single-select segmented button "to select one option from a set,
switch between views, or sort elements from up to five options"
([Segmented buttons: Guidelines](https://m3.material.io/components/segmented-buttons/guidelines)).
So on stated purpose the two components overlap.

They separate on everything else.

### Tabs own the "destination + controlled region" pattern

- **Spec:** primary tabs "display an app's main content destinations"; secondary tabs
  "display related content within a content area"
  ([Tabs: Overview](https://m3.material.io/components/tabs/overview)).
- **Spec:** "Tabs control the UI region displayed below them."
  ([Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines), *Choosing the
  tab variant*.) No comparable statement exists for segmented buttons or button groups.
- **Spec:** the tab container "should always extend the full width of the window and be
  divided into equal sections, one for each tab", and is "defined by a divider on the
  bottom edge to separate it from the content below" ([Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines),
  *Anatomy → Container*). Tabs are structurally tied to the pane underneath them.
- **Spec:** M3 draws the line explicitly on the navigation bar page: "Use navigation for
  distinct pages and tabs for related content within a page"
  ([Navigation bar: Guidelines](https://m3.material.io/components/navigation-bar/guidelines)).

### Segmented buttons are laid out as a selection control, not a region switcher

- **Spec:** "Don't allow segmented buttons to span the full width of larger screens or
  panes. This can leave too much padding on either side of the segment label, making the
  button less usable." Also: "Segmented buttons should have adequate margins from the edge
  of the viewport or frame."
  ([Segmented buttons: Guidelines](https://m3.material.io/components/segmented-buttons/guidelines),
  *Placement*.) This is the opposite of the tab container rule above.
- **Spec:** segmented buttons *may* be placed on other components — "such as bottom sheets
  or full-screen dialogs" (same section). So placing one inside a popup is not itself
  against the spec; spanning the popup's width is.
- **Spec:** the anatomy has a container, segments, optional icon, optional label, and a
  selected icon — **no divider and no active indicator**
  ([Segmented buttons: Guidelines](https://m3.material.io/components/segmented-buttons/guidelines),
  *Anatomy*).

### Segmented buttons are deprecated

- **Spec:** "Segmented buttons are no longer recommended in the Material 3 expressive
  update. For those who have updated, use the connected button group instead, which has
  mostly the same functionality but with an updated visual design." This banner appears at
  the top of the Overview, Guidelines, and Specs pages
  ([Segmented buttons: Overview](https://m3.material.io/components/segmented-buttons/overview)).
- **Spec:** the Button groups pages confirm the replacement — connected button group is
  listed as "Available as segmented button" in baseline M3 and "Available" in M3
  Expressive ([Button groups: Specs](https://m3.material.io/components/button-groups/specs)).
- **Ambiguity in the spec, worth flagging.** The hover definition M3 renders for
  "segmented button" *on the Button groups pages* says something different from the
  segmented-buttons page itself: "Note: They're deprecated in the expressive update. Use a
  nav rail instead." One first-party page says replace with a connected button group,
  another says replace with a navigation rail. Both were read on 2026-07-30 on
  [Button groups: Overview](https://m3.material.io/components/button-groups/overview) and
  [Button groups: Guidelines](https://m3.material.io/components/button-groups/guidelines).
- **Spec (tabs are not deprecated):** the Tabs pages carry no "M3 Expressive update" or
  deprecation section; their only version section is "Differences from M2"
  ([Tabs: Overview](https://m3.material.io/components/tabs/overview)).

### Counts

- **Segmented buttons — 2 to 5, confirmed at the source.** "Segmented buttons can have 2-5
  segments." And as a Do/Don't pair: "Segmented buttons are best used for selecting between
  2 and 5 choices" / "Don't use more than five segments in a single segmented button …
  If you have more than five choices, consider using another component, such as chips."
  ([Segmented buttons: Guidelines](https://m3.material.io/components/segmented-buttons/guidelines),
  *Anatomy → Segments*.) The commonly cited 2–5 figure is accurate.
- **Tabs — soft maximum of four, no minimum.** "Avoid using more than four tabs at once.
  At five or more tabs, the container becomes cramped."
  ([Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines), *Responsive
  layout*.) Countered elsewhere by "Tabs can horizontally scroll, so a UI can have as many
  tabs as needed" ([Tabs: Overview](https://m3.material.io/components/tabs/overview)) —
  the four-tab ceiling applies to fixed tabs.
- **Silence:** no minimum tab count is stated anywhere on the Tabs Overview, Guidelines,
  Specs, or Accessibility pages.

---

## 2. Primary vs secondary tabs

| | Primary | Secondary |
|---|---|---|
| Purpose | "display an app's main content destinations" | "display related content within a content area" |
| Placement | top of the content pane, under an app bar | "always placed below primary tabs" |
| When | "should be used when just one set of tabs are needed" | "necessary when a screen requires more than one level of tabs" |
| Icons | icon optional, part of the anatomy | **no icon in the anatomy** — container, badge, label, divider, indicator |
| Indicator | 3dp tall, hugs the label | 2dp tall, spans the tab |
| Function | — | "their function is identical to primary tabs" |

Sources: [Tabs: Overview](https://m3.material.io/components/tabs/overview),
[Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines) (*Usage*, *Choosing
the tab variant*, *Placement*), [Tabs: Specs](https://m3.material.io/components/tabs/specs)
(the *Primary tabs* and *Secondary tabs* anatomy lists differ by exactly the icon entry).

**Which fits two destinations in a small popup:** primary. The deciding sentence is not
about screen size at all — it is "Primary tabs … should be used when just one set of tabs
are needed" and "Secondary tabs … are necessary when a screen requires more than one level
of tabs". A single level of tabs is a primary tab row regardless of the container it sits
in. Secondary tabs are additionally defined as always sitting *below* primary tabs, which
cannot hold when there is no primary row.

**Inference:** the Compose doc comments restate the same rule and reinforce that the
distinction is level-of-hierarchy, not size — `SecondaryTabRow` is documented as "used
within a content area to further separate related content and establish hierarchy"
([TabRow.kt](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/TabRow.kt)).

---

## 3. Anatomy and measurements

### Primary tabs — anatomy

Container, icon (optional), badge (optional), label, divider, active indicator
([Tabs: Specs](https://m3.material.io/components/tabs/specs)).

### Measurements (from the Specs table)

| Attribute | Value |
|---|---|
| Container height (label text only) | 48dp |
| Container height (icon and label text) | 64dp |
| Icon size | 24dp |
| Divider height | 1dp |
| Primary active indicator height | 3dp |
| Secondary active indicator height | 2dp |
| Active indicator shape | 3, 3, 0, 0 |
| Active indicator minimum length | 24dp |
| Padding between inline icon and text | 8dp |
| Padding between inline text and badge | 4dp |
| Overlap of badge on stacked icon | 6dp |

Source: [Tabs: Specs](https://m3.material.io/components/tabs/specs), *Measurements*.

Prose on the same page, verbatim in substance:

- "Tabs are divided into equal sections, with labels and icons positioned vertically
  centered. The divider is included in the height, placed inside the container."
- "Primary tab active indicators are inset 2dp on each side, have a fully rounded corner
  radius, and a minimum length of 24dp."

**Ambiguity in the spec.** The prose says the primary indicator has "a fully rounded corner
radius"; the table says the active indicator shape is `3, 3, 0, 0` (top corners 3dp, bottom
corners square). These are not reconcilable from the page alone. The token set resolves it
towards a 3dp radius on all four corners — see below. The "inset 2dp on each side" phrase
is likewise unexplained: it is not obviously compatible with an indicator that hugs a label
of arbitrary width, and the page does not say what it is inset from.

### Does the indicator span the tab or hug the label?

The spec pages never state this in words. The first-party implementation does, unambiguously.

**Verified in source** — [`TabRow.kt`](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/TabRow.kt),
androidx-main:

```kotlin
// PrimaryTabRow default indicator
TabRowDefaults.PrimaryIndicator(
    modifier = Modifier.tabIndicatorOffset(selectedTabIndex, matchContentSize = true),
    width = Dp.Unspecified,
)

// SecondaryTabRow default indicator
TabRowDefaults.SecondaryIndicator(
    Modifier.tabIndicatorOffset(selectedTabIndex, matchContentSize = false)
)
```

`matchContentSize` is documented in the same file as "this modifier can also animate the
width of the indicator to match the content size of the tab". And the two indicator
composables differ in exactly the expected way — `SecondaryIndicator` is a
`Box(modifier.fillMaxWidth().height(height)…)`, while `PrimaryIndicator` is a `Spacer` with
`requiredWidth(width)`, whose *default* `width` is `24.dp` (the spec's minimum length),
overridden to `Dp.Unspecified` by `PrimaryTabRow` so the content-derived width wins.

- **Primary indicator: hugs the label.**
- **Secondary indicator: spans the full tab width.**

### Icon + label rules

- **Spec:** icons are optional on primary tabs and are not part of the secondary tab
  anatomy at all ([Tabs: Specs](https://m3.material.io/components/tabs/specs)).
- **Spec:** "Don't use tabs with both icons and text labels on only some tabs, but not
  others." Icon-only is allowed but cautioned: "Icons alone aren't as effective as text
  labels at communicating complex content" ([Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines),
  *Anatomy → Icon*).
- Adding an icon changes the container height from 48dp to 64dp (Specs table above).

### Divider

- **Spec:** part of the anatomy, 1dp, "included in the height, placed inside the
  container", sits on the bottom edge to separate the tab row from the content below
  ([Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines) *Anatomy →
  Container*; [Tabs: Specs](https://m3.material.io/components/tabs/specs)).

### Colour roles

| Element | Primary tabs | Secondary tabs |
|---|---|---|
| Container | Surface | Surface |
| Active label | Primary | On surface |
| Active icon | Primary | (no icon in anatomy) |
| Inactive label | On surface variant | On surface variant |
| Inactive icon | On surface variant | — |
| Divider | Outline variant | Outline variant |
| Active indicator | **Primary** | **Primary** |

Source: the *Primary tabs color* / *Secondary tabs color* role lists on
[Tabs: Specs](https://m3.material.io/components/tabs/specs).

**Verified in source** — `PrimaryNavigationTabTokens` (token set `v0_162`) confirms every
row: `ActiveIndicatorColor = Primary`, `ActiveIndicatorHeight = 3.dp`,
`ActiveIndicatorShape = RoundedCornerShape(3.dp)`, `ContainerColor = Surface`,
`ContainerHeight = 48.dp`, `IconAndLabelTextContainerHeight = 64.dp`, `IconSize = 24.dp`,
`ActiveLabelTextColor = Primary`, `InactiveLabelTextColor = OnSurfaceVariant`,
`LabelTextFont = TitleSmall`.
`SecondaryNavigationTabTokens` gives `ActiveLabelTextColor = OnSurface`,
`InactiveLabelTextColor = OnSurfaceVariant`, `ContainerHeight = 48.dp`,
`DividerHeight = 1.dp`, `LabelTextFont = TitleSmall`.
([PrimaryNavigationTabTokens.kt](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/PrimaryNavigationTabTokens.kt),
[SecondaryNavigationTabTokens.kt](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/SecondaryNavigationTabTokens.kt))

Three places where the published implementation and the spec page diverge — note them
before treating either as authoritative:

1. `ActiveIndicatorShape` is `RoundedCornerShape(3.dp)` — 3dp on **all four** corners, not
   the `3, 3, 0, 0` of the spec table.
2. Compose's `SecondaryIndicator` defaults its height to
   `PrimaryNavigationTabTokens.ActiveIndicatorHeight` (**3dp**), while the spec table says
   the secondary indicator is **2dp**.
3. `SecondaryNavigationTabTokens.DividerColor = SurfaceVariant`, while the spec page's
   colour list says **Outline variant**. `SurfaceVariant` is the older M3 mapping;
   `OutlineVariant` is what the current spec page shows.

Typography: the token set puts both tab variants' labels on **title small**. The spec pages
say only that labels "should be short and succinct".

### For contrast — segmented button measurements and colours

Not the recommended component here, but recorded because it was asked for.

| Attribute | Value |
|---|---|
| Container width | dynamic, based on labels |
| Segment width | container width / total segments |
| Height | 40dp |
| Outline width | 1dp |
| Label alignment | center |
| Left/right padding | min 12dp |
| Padding between elements | 8dp |
| Target size | 48dp |
| Shape | fully rounded corners |
| Density | each step down removes 4dp from the height |

Colour roles: **On surface** (unselected label/icon), **Outline** (border),
**Secondary container** (selected segment fill), **On secondary container** (selected
label/icon). Sources: [Segmented buttons: Specs](https://m3.material.io/components/segmented-buttons/specs);
**verified in source** in `OutlinedSegmentedButtonTokens` (`ContainerHeight = 40.dp`,
`OutlineColor = Outline`, `OutlineWidth = 1.dp`,
`SelectedContainerColor = SecondaryContainer`,
`SelectedLabelTextColor = OnSecondaryContainer`, `Shape = CornerFull`, `IconSize = 18.dp`,
`LabelTextFont = LabelLarge`)
([OutlinedSegmentedButtonTokens.kt](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/OutlinedSegmentedButtonTokens.kt)).

**This is the sharpest visual answer to "which role fills what":** an active *segment* is
filled with **secondary container**; an active *tab* has no fill at all — only a
**primary**-coloured indicator bar and **primary**-coloured label.

The M3 Expressive replacement, the connected button group, uses 2dp inner padding at every
size and has no colour of its own — it inherits the button style used inside (filled,
tonal, outlined, elevated)
([Button groups: Specs](https://m3.material.io/components/button-groups/specs)).

---

## 4. Tabs inside a popup, menu, or small container

**One sentence of guidance exists, and it is favourable:**

> "Tabs can be joined with components like app bars, embedded in a specific UI region, or
> nested within components like cards and sheets. Tabs control the UI region displayed
> below them."
>
> — [Tabs: Guidelines](https://m3.material.io/components/tabs/guidelines), *Choosing the
> tab variant*

That is the whole of it. Beyond that sentence:

- **Silence.** The Tabs Overview, Guidelines, Specs, and Accessibility pages define no
  popup or small-container variant, no reduced height, no alternate density, and no
  minimum container width. The only sizing rule is the opposite one — the container
  "should always extend the full width of the window".
- **Silence.** [Menus: Guidelines](https://m3.material.io/components/menus/guidelines),
  [Dialogs: Guidelines](https://m3.material.io/components/dialogs/guidelines), and
  [Cards: Guidelines](https://m3.material.io/components/cards/guidelines) were each read in
  full on 2026-07-30 and contain **no mention** of tabs or segmented buttons. The
  "nested within cards and sheets" allowance is stated only from the Tabs side; the Cards
  page does not corroborate or elaborate on it.
- **Silence.** Tabs have no density scale. Segmented buttons do ("Density is only applied
  to the height … each step down in density removes 4dp"), which is the only
  small-container accommodation either component offers, and it belongs to the deprecated
  one.

Anything more specific about tabs in a 700 px popup would be extrapolation. The spec does
not go there.

---

## 5. Two destinations specifically

- **No discouragement of a two-tab set exists in the spec.** The Tabs pages state a
  ceiling ("Avoid using more than four tabs at once") and no floor.
- **M3 actively routes two-destination cases towards tabs.** From the navigation bar
  Don'ts: "Don't use a navigation bar for fewer than three destinations. Instead, use
  tabs." And the caption beneath: "Use navigation for distinct pages and tabs for related
  content within a page."
  ([Navigation bar: Guidelines](https://m3.material.io/components/navigation-bar/guidelines))
- **Segmented buttons are not discouraged for view switching *by purpose*** — "switch
  views" is in the definition, and two segments is the stated minimum. They are
  discouraged (a) as a component, by the M3 Expressive deprecation, and (b) in this layout
  specifically, by the rule against spanning the full width of a pane.
- **Silence.** Nothing in the spec says a two-tab row is degenerate, or that two
  destinations should instead be a toggle, switch, or segmented control.

---

## What this implies for a two-destination popup

The spec points to a **fixed primary tab row with two label-only tabs**, spanning the full
width of the card, with a divider on its bottom edge and the pane below it as its
controlled region.

Why, restricted to what the spec actually says:

1. The control switches between *destinations* that own the region below it. That is the
   defined job of tabs — "Tabs control the UI region displayed below them" — and no
   equivalent statement exists for segmented buttons or button groups.
2. There is one level of tabs, so it is **primary**, not secondary: "Primary tabs …
   should be used when just one set of tabs are needed." Secondary tabs are defined as
   always sitting below primary tabs, which cannot apply here.
3. The intended control spans the top of a 700 px card. Tabs are specified to do exactly
   that ("should always extend the full width … divided into equal sections"). Segmented
   buttons are specified not to ("Don't allow segmented buttons to span the full width of
   larger screens or panes").
4. Two tabs is inside the spec's stated range — under the four-tab ceiling, with no floor
   — and M3 names tabs as the correct component when there are fewer than three
   destinations.
5. Segmented buttons carry a standing "no longer recommended" banner on every one of their
   spec pages; tabs carry none.

Concrete numbers that follow directly from the cited spec, for two label-only tabs:

- Container **48dp** tall — which matches the 48 px control height already planned — with
  the **1dp divider included inside** that height, not added to it.
- Two equal-width sections, each 350 px of the 700 px card.
- Active indicator **3dp** tall, **hugging the label** rather than spanning the section
  (verified in `PrimaryTabRow`'s `matchContentSize = true`), minimum length 24dp, corner
  radius 3dp (per the token set; the spec page's prose says "fully rounded" and its table
  says `3, 3, 0, 0` — pick one and note the divergence).
- Colours: container `m3surface`, active indicator and active label `m3primary`, inactive
  label `m3onSurfaceVariant`, divider `m3outlineVariant`. Label typography: title small.
- Labels only. Adding icons would push the container to 64dp, and the spec requires
  all-or-none: "Don't use tabs with both icons and text labels on only some tabs, but not
  others."

Two things the spec does **not** authorise, and which should be treated as open design
decisions rather than compliance:

- Any reduction of the 48dp height for the popup context. Tabs have no density scale and
  no small-container variant.
- Any claim that M3 forbids segmented buttons for view switching. It does not; it forbids
  the full-width layout, and deprecates the component. If the design wants a pill-shaped
  filled toggle instead, the honest framing is that it departs from the tab pattern for
  visual reasons, not that the spec demanded it.

---

## Pages read (all 2026-07-30)

- https://m3.material.io/components/tabs/overview
- https://m3.material.io/components/tabs/guidelines
- https://m3.material.io/components/tabs/specs
- https://m3.material.io/components/tabs/accessibility
- https://m3.material.io/components/segmented-buttons/overview
- https://m3.material.io/components/segmented-buttons/guidelines
- https://m3.material.io/components/segmented-buttons/specs
- https://m3.material.io/components/button-groups/overview
- https://m3.material.io/components/button-groups/guidelines
- https://m3.material.io/components/button-groups/specs
- https://m3.material.io/components/navigation-bar/guidelines
- https://m3.material.io/components/menus/guidelines (no mention of tabs)
- https://m3.material.io/components/dialogs/guidelines (no mention of tabs)
- https://m3.material.io/components/cards/guidelines (no mention of tabs)

First-party implementation, `androidx/androidx` @ `androidx-main`:

- `compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/TabRow.kt`
- `compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/PrimaryNavigationTabTokens.kt`
- `compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/SecondaryNavigationTabTokens.kt`
- `compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/OutlinedSegmentedButtonTokens.kt`

`m3.material.io` is a client-rendered SPA; plain HTTP fetches return only the page title.
The pages above were read through a headless browser after the app finished rendering.
