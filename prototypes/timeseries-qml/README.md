# QML timeseries prototype

Throwaway prototype for “How a timeseries plot is drawn in QML.” It compares three contracts at the dashboard card’s intended density:

- **A — Canvas parity:** optional second line, low-alpha fill, eased dynamic scale, and per-frame smooth scroll.
- **B — Shape parity:** the same visible contract, rebuilt as `ShapePath`/`PathPolyline` so renderer choice can be judged without changing the design.
- **C — Sampled Shape:** optional second line, no fill, immediate padded scale, and one geometry update per sample.

Run it from this worktree:

```sh
qs -p prototypes/timeseries-qml
```

Use the CPU and Network scenarios, inject a spike, and reset the ring to see the below-two-samples state. Switch variants with the bottom arrows or the keyboard’s left/right arrows.

## Verdict

Use `ShapePath`/`PathPolyline` and rebuild geometry once per one-second sample. The widget accepts an optional second series. Single-series plots get a low-alpha fill; dual-series plots use lines only so their overlap stays legible. The caller owns the vertical scale: bounded metrics supply their fixed maximum, while network supplies a shared, smoothed maximum with a floor. With fewer than two samples, the plot shows a collecting message; the card’s headline remains the current-value display.
