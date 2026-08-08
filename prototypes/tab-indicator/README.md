# PROTOTYPE — tab indicator motion (#136)

Throwaway. Not imported by the shell, not part of the test suite, not intended to merge
into `main`. It exists to answer one question and then to be read, not maintained.

## The question

Switching tabs animates `DashboardCard.implicitWidth`. `DashTabBar`'s indicator derives its
target from `tab.labelX`, which is a function of the delegate's laid-out `width` — the card's
**animating** width. What should the indicator's geometry be computed from instead?

## Run it

```
qs -p prototypes/tab-indicator
```

A `FloatingWindow`, so it can run beside the live shell without killing it. Three tabs on a
card that animates between three destination widths, and chips to switch variant and to slow
the whole thing down 3× or 8× — the artefact lasts 200ms at full speed, which is too fast to
see but not too fast to feel.

## The variants

- **0 · live geometry (today)** — indicator target from `activeTab.labelX` / `labelWidth`.
- **1 · settled stride** — index arithmetic over the bar's settled width, published down from
  the card before its `Behavior`. What caelestia's `Tabs.qml` does with `nonAnimWidth`.
- **2 · animated index** — animate a real-valued `animIndex` between tab indices and keep
  position an exact function of the *live* stride, so no `Behavior` sits on `x` at all.

## Reading it headlessly

There is no display on the machine that built this, so the two env vars below print what the
eye would otherwise have to catch.

```
QT_QPA_PLATFORM=offscreen WAYLAND_DISPLAY= PROTO_AUTOPILOT=1 qs -p prototypes/tab-indicator
QT_QPA_PLATFORM=offscreen WAYLAND_DISPLAY= PROTO_AUTOPILOT=1 PROTO_TRACE=1 qs -p prototypes/tab-indicator
```

`PROTO_AUTOPILOT` drives every variant through every switch and prints one `SAMPLE` line per
transition; `PROTO_TRACE` adds a per-frame `TRACE` line. `settled=` on a `SAMPLE` line is the
distance still left to travel 150ms *after* the move should have finished — the number that
turned out to matter.

## What it found

The findings are on issue #136. The short version: variant 0's indicator does not move at all
while the card resizes, then slides afterwards — so the switch takes two animations' worth of
time and the indicator arrives a beat behind everything else.
