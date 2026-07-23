# AGENTS.md

> Quickshell docs and type links below target **v0.3.0**. Check the installed
> version with `qs --version`; if it is newer, the API and the `docs/v0.3.0/`
> URLs may have changed — bump them.

## This is Quickshell, not a normal QML/Qt app

Quickshell is a QML framework for building Wayland desktop shells. Treat this as
a shell config, not a QtQuick application.

- Entry point is `shell.qml` (root type `ShellRoot`, with `//@ pragma UseQApplication`).
- It is run by the `quickshell` binary — there is **no build step and no compile**.
- Files **hot-reload on save** into the already-running instance.

## Conventions

1. **Imports:** always `import qs.<path>` (rooted at this folder). Never relative
   imports like `import "../services"`.
2. **Never create a `qmldir`.** Quickshell resolves `qs.*` paths and singletons
   automatically; a hand-written `qmldir` is unnecessary and wrong here.
3. **Windows:** use `PanelWindow` (layer-shell bars/overlays) or `FloatingWindow`.
   Never plain `Window`/`ApplicationWindow`.
4. **Theming:** pull from the `Appearance` singleton — `Appearance.colors.*`,
   `Appearance.font`, `Appearance.rounding`, `Appearance.sizes`. Do not hardcode
   colors or sizes (the palette is matugen-driven and overwritten at runtime).
5. **Reuse first.** Before writing new code, check `modules/common/widgets/`
   (styled components: `RippleButton`, `StyledSlider`, `MaterialSymbol`, …),
   `modules/common/functions/` (`ColorUtils`, `FileUtils`, `StringUtils`, `Fuzzy`),
   and `services/` (system integrations already exist).
6. **New system integration** = a `pragma Singleton` in `services/` wrapping the
   relevant `Quickshell.Services.*` type behind a clean API (see `services/Audio.qml`
   wrapping Pipewire). Services are referenced by type name via `import qs.services`.
7. **Sizing:** let implicit size flow from children up; set actual size via anchors.
   Never use `childrenRect` for implicit size — it binds actual geometry back into
   the size calculation and creates a binding loop.
8. **Layer surfaces:** set `WlrLayershell.namespace: "quickshell:<name>"` (Hyprland
   layer rules match on this namespace).

## Running & verifying

- Started by Hyprland autostart as bare `quickshell` (default config). This config
  directory is a git submodule (`quickshell_config.git`).
- **You have no display. You cannot see the result and cannot visually verify a
  change. Do not claim a change is "verified working"** — report it as applied and
  ask the user to confirm visually.
- QML errors (bad bindings, missing types, zero-sized items) surface in
  quickshell's stderr/log, not as a build failure.

## IPC (runtime control)

Actions reachable from keybinds are exposed via `IpcHandler` and invoked from
Hyprland with `qs ipc call <target> <function>`. When adding a feature that needs
a keybind, expose it as an `IpcHandler` target.

Existing targets: `session`, `gamingMode`, `brightness`, `powerProfile`, `zoom`,
`warp`, `launcher`. Some toggles also use a Hyprland global (`quickshell:<name>`).

## Type reference

Full docs: `https://quickshell.org/docs/v0.3.0/types/<Module>/<Type>`
(e.g. `Quickshell/PanelWindow`, `Quickshell.Io/Process`). Types used in this repo:

- **PanelWindow** (`Quickshell`) — layer-shell bar/overlay/popup. Size via anchors +
  implicit size, not `width`/`height`.
- **FloatingWindow** (`Quickshell`) — normal desktop window.
- **Variants** (`Quickshell`) — one instance per item in a model; use it for
  per-monitor surfaces instead of manual loops.
- **LazyLoader** (`Quickshell`) — defer/async-load content; `active:` gates loading.
- **Singleton** (`Quickshell`) — `pragma Singleton` at the top, `Singleton` as the
  root item; how every service is built.
- **Process** (`Quickshell.Io`) — run external commands; use this rather than
  shelling out by other means.
- **IpcHandler** (`Quickshell.Io`) — expose callable targets (see IPC section).
- **WlrLayershell** (`Quickshell.Wayland`) — layer-shell attached props (`namespace`,
  layer, anchors, exclusive zone) for `PanelWindow`.
- Service modules in use: `Quickshell.Services.{UPower, SystemTray, Mpris, Pipewire,
  Notifications}`, `Quickshell.Bluetooth`, `Quickshell.Hyprland`, `Quickshell.Widgets`.
