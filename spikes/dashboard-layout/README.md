# Spike: dashboard layout

Throwaway prototype for [#95](https://github.com/bhdai/quickshell_config/issues/95), the
layout ticket on the [datetime popup rewrite map](https://github.com/bhdai/quickshell_config/issues/82).

It exists to answer one question that prose cannot: **does a canvas sized for a calendar
comfortably hold a wallpaper grid**, and at what cell size. Everything here is hardcoded
and none of it should be reused — the real popup is `modules/dashboard/`, built afterwards.

## Running it

```sh
./run.sh          # a normal window on the running session; keys below
./capture.sh      # renders every variant to shots/ with no display, and prints metrics
```

`run.sh` stages a throwaway config holding the spike plus `modules/common` and `assets`,
so it raises one `FloatingWindow` and cannot disturb the live shell. Files still
hot-reload on save.

| key | does |
| --- | --- |
| `←` `→` | cycle the wallpaper grid variant |
| `↑` `↓` | cycle the header variant |
| `Tab` | switch tab |
| `m` | jump to a six-week month and back |

## Variants

**Wallpaper grid** — the geometry question. Cell aspect follows this panel (1920×1200),
not a generic 16:9, because the cell is previewing a screen.

| | columns | rows | cells | cell | footer |
| --- | --- | --- | --- | --- | --- |
| A | 4 | 4 | 16 | 160×100 | none |
| B | 3 | 3 | 9 | 217×136 | none |
| C | 4 | 3 | 12 | 160×100 | 50px paging strip |

**Header** — #87 fixed that the band is full width and 72px and handed the treatment here.
All three keep those numbers: `1` bare band, `2` the band as a filled card matching the
calendar and tiles, `3` weather-forward with a bigger icon and temperature.

## What it renders against

Real: `calendar_layout.js` (symlinked, not copied), `Appearance`, `RippleButton`,
`MaterialSymbol`, `CustomIcon`, the weather SVGs, and the two actual files in
`~/Pictures/wall`. Fake: every weather reading (`mock.js`, holding #84's probe numbers),
and the library, padded to 16 tiles because the grid is the subject and a library of two
is not.

## Offscreen capture has a hole in it — read before trusting a shot

`capture.sh` renders under `QT_QPA_PLATFORM=offscreen` and grabs with `grabToImage`. That
works, but **anything routed through an offscreen render target draws nothing into the
grab**. Measured here, all three:

| | in a grab |
| --- | --- |
| plain `Rectangle`, `Text`, `Image`, `Shape` | draws |
| `Rectangle { clip: true }` | draws |
| `layer.enabled: true` alone | draws |
| `layer.effect:` Qt5Compat `OpacityMask` | **nothing** |
| `QtQuick.Effects` `MultiEffect`, as `layer.effect` or standalone | **nothing** |
| `Quickshell.Widgets` `ClippingRectangle` | **nothing** |

Two consequences the spike works around, both marked at their sites:

- `RippleButton` paints its background through an `OpacityMask` layer effect, so **no
  button background survives a capture**. The today cell draws its own rectangle instead,
  or the one filled day in the month would be missing from every shot. Hover and pressed
  states are still absent from the shots — look at them in `run.sh`, not in a PNG.
- The wallpaper cells use `RoundedImage.qml`, which clips square and paints the corners
  back in with a `Shape`, because `ClippingRectangle` — the primitive the real picker
  should use — captures as nothing.

This is a limit of the capture, not of the shell: geometry and measurement are unaffected,
which is why `tests/lock-clock.sh` and the other offscreen fixtures are still sound. It
does mean an offscreen fixture cannot be used to check anything about a masked or blurred
surface.
