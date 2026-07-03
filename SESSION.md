# SESSION

## Deferred Items

- **Wallpaper picker UI**: During adaptive color planning, the idea of
  porting the dots-hyprland wallpaper picker panel came up. Deferred
  because it's a separate feature (thumbnail grid, directory browsing,
  hyprpaper integration). Should be tackled after the adaptive color
  pipeline is working end-to-end, since the picker would call
  `apply-colors.sh` as part of its wallpaper-switch flow.

- **Light/dark mode toggle**: Currently dark-only. Adding a toggle
  requires testing every component in both modes and adding a UI switch.
  The `MaterialThemeLoader` can be extended to derive `darkmode` from
  `m3background.hslLightness` when this is implemented.

- **Color transition animation**: Instant snap for now. Could add
  `Behavior on color` to `m3colors` properties later for smooth
  cross-fade, but needs performance testing with 30+ simultaneous
  color animations.
