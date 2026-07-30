# Quickshell 0.3.0 wallpaper rendering primitives

Research for [Verify Quickshell 0.3.0's wallpaper rendering primitives](https://github.com/bhdai/quickshell_config/issues/83), performed on 2026-07-30.

## Executive answer

The installed stack is Quickshell 0.3.0 (`quickshell` Arch package `0.3.0-2`) on Qt 6.11.1. A wallpaper can be implemented with one click-through, full-output background `PanelWindow` per `Quickshell.screens` entry and two ordinary `Image` items for the crossfade.

The main constraint is output lifecycle, not drawing. A `ShellScreen` object does not survive a disconnect/reconnect, and first-party Dank reports show layer surfaces being recreated too early or remaining stale after a `wl_output` rebind. A small, debounced surface reattach when a screen name reappears is justified. Porting Dank's permanent three-second `frameSwapped` watchdog is not justified yet: no Quickshell or Qt report found establishes that watchdog as necessary for a simple, always-updating two-`Image` wallpaper. Make repeated DPMS and physical hotplug an acceptance test and add a watchdog only if that test reproduces a missed swap.

Quickshell has a per-shell cache directory, but no public `CachingImage` or wallpaper-thumbnail provider. Dank's component is application code built from `Image.sourceSize`, `grabToImage()`, and a PNG cache. The same primitives are available here. Shader transitions, however, require precompiled `.qsb` files under Qt 6.11; inline GLSL is not supported.

No visual or compositor-runtime claims below were tested locally. This environment has no usable display connection, and the repo explicitly forbids claiming visual verification without one.

## Evidence and confidence labels

- **Verified locally** means observed from installed binaries/packages or this checkout.
- **Documented** means guaranteed or described by official Quickshell/Qt documentation.
- **Verified in source** means read directly from the exact Quickshell v0.3.0 source, commit [`59e9c47`](https://github.com/quickshell-mirror/quickshell/tree/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83).
- **Reported upstream** means a first-party issue or pull request demonstrates a real reproduction, but it is not a general API guarantee.
- **Inference** means the conclusion follows from those facts but still needs a live compositor test.

## 1. Background surface

### Supported configuration

This is the supported shape:

```qml
PanelWindow {
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell:wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    mask: Region { item: Item {} }
}
```

- **Documented:** `PanelWindow` is the edge-attached shell-window type. Opposite anchors force the corresponding dimension to the screen dimension, so all four anchors produce an output-sized surface. `color` is a `QsWindow` property; starting transparent also requests a non-opaque surface format. See [PanelWindow](https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/) and [QsWindow.color/surfaceFormat](https://quickshell.org/docs/v0.3.0/types/Quickshell/QsWindow/).
- **Documented:** `WlrLayershell` is the `PanelWindow` attached object for `zwlr_layer_shell_v1`; its `layer` selects the shell layer. See [WlrLayershell](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlrLayershell/).
- **Documented and verified in source:** `ExclusionMode.Ignore` ignores other panels' exclusion zones and cannot reserve one itself. On Wayland it maps to layer-shell exclusive zone `-1`, exactly the protocol value for “do not move or resize to accommodate exclusive zones.” See [ExclusionMode](https://quickshell.org/docs/v0.3.0/types/Quickshell/ExclusionMode/), [`wlr_layershell.cpp:17-35`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/wayland/wlr_layershell/wlr_layershell.cpp#L17-L35), and the bundled [layer-shell protocol definition](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/wayland/wlr_layershell/wlr-layer-shell-unstable-v1.xml#L152-L181).
- **Verified in source:** the layer surface is created against the selected screen's real `wl_output`; if the screen is a Qt placeholder or otherwise has no output, Quickshell warns and lets the compositor choose. See [`surface.cpp:133-160`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/wayland/wlr_layershell/surface.cpp#L133-L160).

### Empty-region click-through

`mask: Region { item: Item {} }` is valid in 0.3.0 and is an empty input region:

- **Documented:** a non-null `QsWindow.mask` defines the clickable portion of a window; clicks outside it pass through to windows behind it. An item's geometry defines a `Region`. See [QsWindow.mask](https://quickshell.org/docs/v0.3.0/types/Quickshell/QsWindow/#mask) and [Region.item](https://quickshell.org/docs/v0.3.0/types/Quickshell/Region/).
- **Verified in source:** a default `Item` has zero size, the default `Combine` region builds only that empty geometry, and Quickshell applies `Qt::WindowTransparentForInput` when the computed mask is empty. See [`region.cpp:233-251`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/core/region.cpp#L233-L251) and [`proxywindow.cpp:657-667`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/window/proxywindow.cpp#L657-L667).
- **Inference requiring a live test:** this should deliver pointer input to the desktop surface or ordinary windows beneath it on Hyprland. The Quickshell side is unambiguously input-transparent, but actual target delivery was not exercised here. Test both an empty workspace and a floating window over the wallpaper.

The current repo already uses the same mask contract for notification popups: only the `ListView` is clickable and the rest of its `PanelWindow` passes through ([`modules/notificationPopup/Popups.qml:24-33`](../../modules/notificationPopup/Popups.qml#L24-L33)).

## 2. Per-monitor surfaces and identity

### What the model exposes

- **Documented:** `Quickshell.screens` is a live list of connected `ShellScreen` objects; the official example is `Variants` creating a `PanelWindow` with `screen: modelData` for every screen. Instances are created and destroyed as screens are added and removed. See [Quickshell.screens](https://quickshell.org/docs/v0.3.0/types/Quickshell/Quickshell/#screens) and [Variants](https://quickshell.org/docs/v0.3.0/types/Quickshell/Variants/).
- **Documented:** each `ShellScreen` exposes `name`, `model`, `serialNumber`, `x`, `y`, `width`, `height`, `devicePixelRatio`, physical/logical pixel density, and orientation. See [ShellScreen](https://quickshell.org/docs/v0.3.0/types/Quickshell/ShellScreen/).
- **Verified locally:** the installed 0.3.0 tooling metadata contains those same properties. `name`, `model`, and `serialNumber` are constant for one `ShellScreen`; geometry and density properties notify when they change.
- **Verified in source:** `name`, `model`, and `serialNumber` delegate to the underlying Qt `QScreen`; geometry delegates to its position/size and scale to `devicePixelRatio`. See [`qmlscreen.cpp:36-124`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/core/qmlscreen.cpp#L36-L124).

This repo already follows the documented pattern for bars ([`modules/bar/Bar.qml:29-45`](../../modules/bar/Bar.qml#L29-L45)).

### Stability across `wl_output` rebind

The `ShellScreen` object itself is never a persistent key:

- **Documented:** disconnecting makes stored screen objects dangling, and reconnecting does not reconnect the old object. See the warning in [ShellScreen](https://quickshell.org/docs/v0.3.0/types/Quickshell/ShellScreen/).
- **Verified in source:** Quickshell reuses a wrapper only when the new `QScreen*` is pointer-identical; otherwise it constructs a new wrapper and deletes the old one. See [`qmlglobal.cpp:108-136`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/core/qmlglobal.cpp#L108-L136).

Candidate keys:

| Candidate | What is verified | Suitability |
| --- | --- | --- |
| `name` | OS/compositor output name, normally `DP-1`, `HDMI-1`, or `eDP-1` | Best key for “this connector.” Stable when the same connector is rebound, but changes when the physical monitor moves ports or connector numbering changes. |
| `serialNumber` | Exposed directly from Qt/Wayland | Best available physical-display key when non-empty and unique. Neither Qt nor Quickshell documents non-emptiness or uniqueness, so it needs a fallback. |
| `model` | Exposed directly from Qt/Wayland | Usually survives a rebind and port move, but identical monitor models collide and some outputs provide an empty/generic model. Not sufficient alone. |
| `model` plus occurrence index | Dank sorts screens by geometry and indexes identical models ([`SettingsData.qml:2615-2655`](https://github.com/AvengeMedia/DankMaterialShell/blob/75eac83b475a/quickshell/Common/SettingsData.qml#L2615-L2655)) | Survives connector renumbering only while relative monitor layout and the identical-model set remain unchanged. It is a useful fallback, not a durable identity guarantee. |
| geometry (`x/y/width/height`) | Live mutable properties | Never an identity key: layout, mode, rotation, and mirroring can change it. |
| `devicePixelRatio` | Live scale value | Never an identity key and commonly shared by multiple outputs. |

**Inference for the later spec:** persist a dedicated string key, preferring a non-empty `serialNumber`, then a documented fallback such as model-plus-position index, then `name`. Store the current output `name` separately if IPC must address connectors. Whichever policy is selected must define collision handling because no exposed field is documented as globally unique.

## 3. Hotplug and DPMS on Hyprland

### What is established

- **Verified in source:** Quickshell's output tracker observes Qt screen removal/addition, but contains a FIXME for an output removed before full initialization ([`output_tracking.cpp:14-86`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/wayland/output_tracking.cpp#L14-L86)).
- **Verified in source:** changing a window's `screen` already hides it, calls Qt's `setScreen()`, and shows it again. Layer-shell windows additionally disallow backing-window reuse after becoming invisible because Qt may attach a buffer before configure and cause a protocol error. See [`proxywindow.cpp:399-426`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/window/proxywindow.cpp#L399-L426) and [`wlr_layershell.cpp:108-115`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/wayland/wlr_layershell/wlr_layershell.cpp#L108-L115). In other words, output/surface lifecycle quirks are already a concern in Quickshell itself.
- **Reported upstream:** Dank's merged [surface-recovery PR](https://github.com/AvengeMedia/DankMaterialShell/pull/2457) attributes missing wallpapers after DPMS to `Variants` recreating wallpaper `PanelWindow`s while the compositor output is still initializing, leaving an image at 0×0. Its two delayed recreation passes fixed the reporter's Niri setup.
- **Reported upstream:** a later [single-output-rebind report](https://github.com/AvengeMedia/DankMaterialShell/issues/2579) includes `wl_output` drop/rebind logs and shows that recovery limited to “all screens disappeared” missed an external output while the internal output remained. This is direct evidence for tracking individual screen reappearance.
- **Reported upstream, Hyprland:** [Screen freezes when using DMS' built in screen saver](https://github.com/AvengeMedia/DankMaterialShell/issues/2778) reports active Hyprland 0.55.4, Arch's Quickshell 0.3.0, a black/unresponsive display after DPMS, and wallpapers no longer loading. It remains open, so it establishes exposure on Hyprland but not an accepted root cause or fix.
- **Reported upstream, broader Quickshell:** [quickshell-mirror/quickshell#629](https://github.com/quickshell-mirror/quickshell/issues/629) reports repeatable crashes while `Quickshell.screens`/`Variants` trees are destroyed on monitor hotplug under Sway. It is a different failure mode and a newer revision, but confirms screen hotplug is not merely a Dank wallpaper-state problem.

No Qt bug report or Quickshell issue was found that independently ties a missed `frameSwapped` signal to `mFrameCallbackTimedOut` and validates Dank's exact three-second watchdog. Dank's current source states that diagnosis in a comment and bounces `visible` when no swap arrives ([`WallpaperBackground.qml:141-175`](https://github.com/AvengeMedia/DankMaterialShell/blob/75eac83b475a/quickshell/Modules/WallpaperBackground.qml#L141-L175)), but that is application evidence, not an upstream guarantee.

### Decision supported by the evidence

1. Include a **targeted, debounced reattach when an output reappears** in the service design. Track prior connected identities/names across `Quickshell.screens` updates and bounce only the affected wallpaper surface after its replacement `ShellScreen` exists. This addresses the demonstrated rebind race without importing Dank's global two-pass recovery system.
2. Do **not** initially port the three-second `frameSwapped` watchdog, `_settleFrames`, or the render-loop gating around `updatesEnabled`. Those mechanisms are entangled with Dank's shaders, scrolling wallpaper, frozen `ShaderEffectSource`, lock fades, and manual render pausing; the planned service has none of those.
3. Before calling the implementation complete, repeatedly test DPMS off/on and physical unplug/replug on the real Hyprland session, including the case where one of two outputs remains connected. Verify non-zero surface geometry, a successful image change after resume, and pointer pass-through. If a requested update still produces no `frameSwapped`, that observation is the evidence to add a bounded watchdog.

## 4. Image loading, thumbnails, and caching

### Native facilities

- **Documented:** Qt `Image` loads local files synchronously by default; `asynchronous: true` moves local loading to a low-priority thread. Images are internally cached and shared by source, `cache` defaults to true, and Qt recommends bounding user images with `sourceSize`. See [Image performance and properties](https://doc.qt.io/qt-6/qml-qtquick-image.html).
- **Documented:** `sourceSize` bounds the pixels retained for a loaded image rather than merely scaling its painting. JPEG can be scaled during decode without ever loading the whole original into memory. Changing `sourceSize` reloads the source. See [Image.sourceSize](https://doc.qt.io/qt-6/qml-qtquick-image.html#sourceSize-prop).
- **Documented:** `Item.grabToImage()` asynchronously renders an item to an offscreen surface; its result can be saved with `saveToFile()`. The operation copies from GPU to CPU and is explicitly described as costly, so it is suitable for one-time thumbnail creation, not a live preview. See [Item.grabToImage](https://doc.qt.io/qt-6/qml-qtquick-item.html#grabToImage-method) and [QQuickItemGrabResult.saveToFile](https://doc.qt.io/qt-6/qquickitemgrabresult.html#saveToFile).
- **Documented:** `Quickshell.cacheDir` is a per-shell cache directory, normally `~/.cache/quickshell/by-shell/<shell-id>`, and `Quickshell.cachePath(path)` joins a child path. See [Quickshell.cacheDir/cachePath](https://quickshell.org/docs/v0.3.0/types/Quickshell/Quickshell/#cacheDir).
- **Verified locally/source:** Quickshell 0.3.0 has no public `CachingImage` or thumbnail type. Its public image-facing helper is primarily theme-icon resolution; internal `image://qsimage` and `image://qspixmap` providers are backed by C++ handles and are not a general “load arbitrary file and cache thumbnail” API. See the [v0.3.0 Quickshell type index](https://quickshell.org/docs/v0.3.0/types/Quickshell/) and provider registration in [`generation.cpp:55-57`](https://github.com/quickshell-mirror/quickshell/blob/59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83/src/core/generation.cpp#L55-L57).

Dank's `CachingImage` is therefore not a Quickshell primitive. It is application code: it hashes the normalized path, loads at a bounded `sourceSize`, tries a cached PNG first, and calls `grabToImage().saveToFile()` on a miss ([`CachingImage.qml:33-46`](https://github.com/AvengeMedia/dank-qml-common/blob/1919595f0dde4f5bf5ac0baa1902ff6d070971d5/DankCommon/Widgets/CachingImage.qml#L33-L46), [`CachingImage.qml:65-94`](https://github.com/AvengeMedia/dank-qml-common/blob/1919595f0dde4f5bf5ac0baa1902ff6d070971d5/DankCommon/Widgets/CachingImage.qml#L65-L94)). Its wallpaper grid requests 256-pixel thumbnails ([`WallpaperTab.qml:557-568`](https://github.com/AvengeMedia/DankMaterialShell/blob/75eac83b475a/quickshell/Modules/DankDash/WallpaperTab.qml#L557-L568)).

### Cost for a grid

For 16 simultaneously loaded square RGBA thumbnails:

- 256×256×4 bytes is 256 KiB each, or about 4 MiB of uncompressed pixel/texture storage for the page before allocator overhead. Mipmaps, if enabled, add more; Qt `Image.mipmap` is false by default.
- Each distinct source needs an initial decode. `asynchronous: true` prevents those local decodes from blocking the UI thread, while `sourceSize: 256` bounds retained pixels and can reduce JPEG decode memory.
- Qt's in-process cache shares identical sources, but it is not a durable on-disk thumbnail cache. A PNG cache under `Quickshell.cacheDir` avoids repeated full-source decode across launches at the cost of one GPU→CPU grab and PNG write per cache miss.

**Inference:** begin with ordinary asynchronous `Image` delegates bounded to the rendered cell size. With the current two-image library this is enough. Add a disk thumbnail cache only when the library size or measured picker-open latency warrants it. If a disk cache is specified, include file modification metadata in the cache key; Dank's path-only key can serve stale thumbnails after in-place edits.

## 5. Crossfade, shaders, and texture limits

### Two ordinary image layers

A shader is not needed for a fade. Two sibling `Image` items participate in normal Qt Quick source-over composition; holding the old image at opacity 1, loading the next layer, then animating old 1→0 and new 0→1 is the plain crossfade.

- **Documented:** Qt `Image` exposes asynchronous status and opacity is inherited from `Item`; Qt 6.11 also offers `retainWhileLoading`, explicitly trading extra memory for retaining the prior image while a replacement loads. See [Image.status and retainWhileLoading](https://doc.qt.io/qt-6/qml-qtquick-image.html).
- **Documented:** `QsWindow.updatesEnabled` defaults to true; disabling it prevents animations and visual updates from rendering. Do not disable it during a crossfade. See [QsWindow.updatesEnabled](https://quickshell.org/docs/v0.3.0/types/Quickshell/QsWindow/#updatesEnabled).
- **Inference requiring live visual verification:** nothing about a background layer surface changes Qt Quick item composition, so the crossfade should work there. The exact readiness handoff, absence of a flash, and frame delivery after DPMS must be visually tested.

At output resolution, two active RGBA images temporarily require roughly twice one decoded texture: about 15.8 MiB per 1920×1080 output or 63.3 MiB per 3840×2160 output, before overhead.

### ShaderEffect

- **Documented, definitive:** Qt 6 no longer accepts inline GLSL strings for `ShaderEffect`. Vertex and fragment properties are URLs to preprocessed shader packages, normally `.qsb`; shader translation/packing happens offline or by build time. See [ShaderEffect shaders](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html#shaders) and [fragmentShader](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html#fragmentShader-prop).
- **Documented:** `ShaderEffectSource` itself is available and can render an item to a texture, but it always increases video-memory use and usually decreases performance. See [ShaderEffectSource](https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html).

This rules out inline shaders categorically. A checked-in `.qsb` could technically work, but it is already outside this map's scope because it introduces a generated artifact/build step. The two-image fade avoids `ShaderEffectSource` too.

### Maximum texture size

`maxTextureSize: 8192` in Dank is its own conservative constant, not a Quickshell or `Image` property ([`WallpaperBackground.qml:683-686`](https://github.com/AvengeMedia/DankMaterialShell/blob/75eac83b475a/quickshell/Modules/WallpaperBackground.qml#L683-L686)).

Qt documents the true `QRhi::TextureSizeMax` as backend/platform/implementation dependent, typically 4096–16384, with oversized texture creation expected to fail ([QRhi resource limits](https://doc.qt.io/qt-6/qrhi.html#ResourceLimit-enum)). Quickshell 0.3.0 does not expose that resource limit to QML. Therefore:

- 8192 is not a guarantee and should not be described as one.
- Bound wallpaper `sourceSize` to the required physical output size (`logical size × devicePixelRatio`), not the source file's native dimensions.
- A hard 8192 ceiling is a reasonable policy only if the product accepts downscaling outputs above that dimension. Hardware-specific correctness still requires a live render test; an oversized allocation may surface through `QsWindow.resourcesLost`.

## 6. Existing repo precedent

### Images

- The lock wallpaper is an asynchronous `Image` with `PreserveAspectCrop`, `cache: false`, and `sourceSize` bound to the output-sized item. It applies a `MultiEffect` blur through an item layer ([`modules/lock/LockBackground.qml:24-51`](../../modules/lock/LockBackground.qml#L24-L51)).
- Media controls use an asynchronous, cached album-art `Image`, bound `sourceSize`, and `MultiEffect` blur ([`modules/mediaControls/PlayerControl.qml:212-231`](../../modules/mediaControls/PlayerControl.qml#L212-L231)). This is the requested blur precedent; the current line is 225 rather than the ticket's older `:212` pointer.
- Profile and album-art images elsewhere also use `sourceSize`; there is no `grabToImage`, disk thumbnail cache, `ShaderEffect`, `ShaderEffectSource`, or custom image provider in this repo.

### Layer surfaces

- The bar uses `Variants` over `Quickshell.screens`, a transparent `PanelWindow`, and namespace `quickshell:bar`; it leaves the layer at Quickshell's default `WlrLayer.Top` ([`modules/bar/Bar.qml:29-45`](../../modules/bar/Bar.qml#L29-L45)).
- Explicit layer selections are all `WlrLayer.Overlay`: session screen ([`modules/sessionScreen/SessionScreen.qml:21-33`](../../modules/sessionScreen/SessionScreen.qml#L21-L33)), notification popups ([`modules/notificationPopup/Popups.qml:9-16`](../../modules/notificationPopup/Popups.qml#L9-L16)), OSD ([`modules/OSD/BaseOSD.qml:20-28`](../../modules/OSD/BaseOSD.qml#L20-L28)), launcher ([`modules/launcher/Launcher.qml:22-33`](../../modules/launcher/Launcher.qml#L22-L33)), and system-tray overflow ([`modules/bar/SysTrayOverflowPopup.qml:45-50`](../../modules/bar/SysTrayOverflowPopup.qml#L45-L50)).
- The current datetime popup sets a layer-shell namespace but leaves the default layer ([`modules/bar/DateTimePopup.qml:17-30`](../../modules/bar/DateTimePopup.qml#L17-L30)).
- **Verified locally:** there is currently no `WlrLayer.Background` or `WlrLayer.Bottom` usage in this repo. The wallpaper surface will be its first background-layer surface.

## Runtime acceptance checks left open

These cannot be resolved without launching the dev clone on the real or nested compositor:

1. Confirm the background surface is visible below desktop windows on every Hyprland output and the transparent surface itself never flashes.
2. Confirm empty-mask clicks reach desktop bindings and normal windows.
3. Confirm the two-image fade produces frames while both images load and after a DPMS cycle.
4. Repeat DPMS and physical hotplug with one output remaining connected; confirm the targeted reattach restores non-zero geometry and later wallpaper changes.
5. Record actual `name`, `model`, `serialNumber`, geometry, and DPR values before and after reconnect to validate the eventual identity fallback on this hardware.
6. Test an image whose native dimensions exceed the chosen decode bound and, if relevant, an output near the backend's texture limit.

These checks should be run during implementation with `qs -p /home/dai/ghq/github.com/bhdai/quickshell_config`, following the repo's live/dev isolation instructions. No product code was changed during this research.
