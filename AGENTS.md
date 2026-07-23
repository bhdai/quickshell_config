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

## Pull requests

PR titles follow the Conventional Commits specification.

## Running & verifying

- Started by Hyprland autostart as bare `quickshell` (default config). This config
  directory is a git submodule (`quickshell_config.git`).
- **You have no display. You cannot see the result and cannot visually verify a
  change. Do not claim a change is "verified working"** — report it as applied and
  ask the user to confirm visually.
- QML errors (bad bindings, missing types, zero-sized items) surface in
  quickshell's stderr/log, not as a build failure.

## Testing

- Keep pure `string → data` parsing, formatting, and symbol selection in a
  `.pragma library` JavaScript file beside the service that owns it. Keep the QML
  Singleton as a thin shell responsible for `Process` I/O and QML object
  lifecycle. Reserve `modules/common/functions/` for cross-cutting utilities.
- Run the full unit suite with `node --test`. It uses Node's built-in test runner
  with no dependencies, `package.json`, or `node_modules`.
- Tests load the unchanged QML JavaScript source through
  `tests/load-qml-js.mjs`. The loader must evaluate functions in Node's host realm;
  a separate `vm` realm gives returned arrays and objects different prototypes,
  causing `assert.deepEqual` to reject otherwise identical values.
- `.github/workflows/test.yml` runs the required unit-test gate on pushes and
  pull requests into `main`. `.github/workflows/smoke.yml` loads the full shell
  under headless Wayland on pull requests into `main`; it starts non-blocking and
  should become required after it proves stable.
- `qmllint` is deliberately deferred. Quickshell's native VFS resolves `qs.*`,
  but qmllint 1.0 with Qt 6.11.1 hard-crashes with exit 255 and no diagnostic on
  roughly half the repository. Revisit a qmllint gate when that upstream defect
  is fixed.

## Development workflow

There are **two checkouts of the same `quickshell_config.git`**, and which one you
touch matters:

- **Live / deployed:** `~/.config/quickshell` (symlink → `dotfiles/config/quickshell`,
  a submodule of the `dotfiles` superrepo). Autostarted by Hyprland, always kept on
  `main`. **Never do WIP here** — it hot-reloads straight into the running desktop, so
  a broken branch is a broken shell.
- **Dev clone:** `~/ghq/github.com/bhdai/quickshell_config` (standalone). All branch /
  PR / issue work happens here.

Feature loop:

1. Branch in the dev clone (`git switch -c feat-foo`), make changes there.
2. Test it as its own instance, isolated from the live shell:
   ```
   killall quickshell                                # stop the live default
   qs -p ~/ghq/github.com/bhdai/quickshell_config    # run the dev clone (hot-reloads on save)
   # ... iterate ...
   killall quickshell && qs                          # back to the live default
   ```
   Use `-p <path>`, not `-c <name>`: `-c` only resolves configs under
   `~/.config/quickshell/<name>/`, and the dev clone lives outside that tree.
3. PR `feat-foo` → `main` on `quickshell_config`; merge.
4. Land it on the live shell and re-pin the superrepo:
   ```
   git -C ~/.config/quickshell pull                  # live shell hot-reloads to merged code
   git -C ~/ghq/github.com/bhdai/dotfiles add config/quickshell
   git -C ~/ghq/github.com/bhdai/dotfiles commit -m "quickshell: bump submodule"
   ```
   The submodule pointer bump (the second/third commands) is required — without it, a
   fresh machine still checks out the old commit.

`AGENTS.md` here is a symlink target of `CLAUDE.md`; edit `AGENTS.md`. This file is
tracked by `quickshell_config.git`, so it reaches the dev clone the normal way (commit
+ pull), not by editing both copies.

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
