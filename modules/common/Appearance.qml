pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions

/**
 * Appearance - Unified Material 3 design system singleton
 * Replaces Colors.qml and LauncherAppearance.qml with:
 * - m3colors: All 50+ matugen scheme colors (writable at runtime for live palette loading)
 * - colors: Computed layer system + semantic colors + status colors
 * - font, rounding, sizes, animation: UI configuration
 *
 * The m3colors properties are plain (non-readonly) so that MaterialThemeLoader
 * can overwrite them at runtime when a generated colors.json palette is available.
 * Default values reflect the source palette (#95CDF7) and remain in effect until
 * MaterialThemeLoader applies a wallpaper-derived scheme.
 */
Singleton {
    id: root

    // Transparency settings. These only read as frosted glass where Hyprland also grants the
    // surface's layer namespace a `blur` layer rule — nothing in QML can sample what is behind
    // a Wayland surface, so the compositor does the blurring and this only opens the window.
    //
    // The bar is tuned separately and more conservatively: panels are transient and looked at
    // directly, while the bar sits over arbitrary wallpaper all day and its text still has to
    // survive a bright patch.
    //
    // Both surfaces must stay above 0.5 alpha, which is the `ignore_alpha` threshold on their
    // Hyprland blur layer rules. Opening one past that does not make it more frosted, it makes
    // the compositor stop blurring behind it altogether and leaves the transparency standing on
    // its own — the worse of the two failure modes, and the reason the ground values are lower
    // than the effect suggests they should be.
    //
    // The two compose multiplicatively, and that product is the number to reason about: content
    // is painted over its surface's own translucent ground, so the fraction of the backdrop that
    // reaches the eye through a card is background * content, not content alone. A widget is
    // never more see-through than the surface carrying it, which makes each ground the ceiling
    // for everything drawn on it — a panel card lands at 14%, a bar widget at 10%.
    property real configuredBackgroundTransparency: 0.35
    property real configuredContentTransparency: 0.40
    property real configuredBarTransparency: 0.25

    // Gaming mode turns Hyprland's blur off globally. Transparency without blur is unreadable,
    // so it collapses here too, through one flag GamingModeService writes. The dependency only
    // works in that direction: services already import Appearance, so Appearance cannot import
    // them back.
    property bool reducedEffects: false

    // The manual override, deliberately a second property rather than another writer on
    // reducedEffects. GamingModeService holds that one with a Binding, and an imperative write
    // from the IPC handler below would break the binding for good — gaming mode would stop
    // restoring opacity when it exits. Two properties cannot contend.
    property bool transparencyOff: false

    readonly property bool opaque: reducedEffects || transparencyOff

    readonly property real backgroundTransparency: opaque ? 0 : configuredBackgroundTransparency
    readonly property real contentTransparency: opaque ? 0 : configuredContentTransparency
    readonly property real barTransparency: opaque ? 0 : configuredBarTransparency

    IpcHandler {
        target: "appearance"

        function toggleTransparency(): void {
            root.transparencyOff = !root.transparencyOff;
        }

        function transparencyEnabled(): bool {
            return !root.opaque;
        }
    }

    // Material 3 color scheme (from matugen - source #95CDF7)
    // Properties are writable so MaterialThemeLoader can apply a live palette.
    property QtObject m3colors: QtObject {
        property bool darkmode: true

        // Primary
        property color m3primary: "#95CDF7"
        property color m3onPrimary: "#00344E"
        property color m3primaryContainer: "#004C6E"
        property color m3onPrimaryContainer: "#C9E6FF"
        property color m3inversePrimary: "#006590"
        property color m3primaryFixed: "#C9E6FF"
        property color m3primaryFixedDim: "#8BCBF5"
        property color m3onPrimaryFixed: "#001E2F"
        property color m3onPrimaryFixedVariant: "#004C6E"

        // Secondary
        property color m3secondary: "#B7C9D9"
        property color m3onSecondary: "#22323F"
        property color m3secondaryContainer: "#384956"
        property color m3onSecondaryContainer: "#D3E5F5"
        property color m3secondaryFixed: "#D3E5F5"
        property color m3secondaryFixedDim: "#B7C9D9"
        property color m3onSecondaryFixed: "#0C1D29"
        property color m3onSecondaryFixedVariant: "#384956"

        // Tertiary
        property color m3tertiary: "#CEC0E8"
        property color m3onTertiary: "#352B4B"
        property color m3tertiaryContainer: "#4C4163"
        property color m3onTertiaryContainer: "#EADDFF"
        property color m3tertiaryFixed: "#EADDFF"
        property color m3tertiaryFixedDim: "#D1C1E9"
        property color m3onTertiaryFixed: "#201535"
        property color m3onTertiaryFixedVariant: "#4C4163"

        // Error
        property color m3error: "#FFB4AB"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000A"
        property color m3onErrorContainer: "#FFDAD6"

        // Surface & Background
        property color m3background: "#101417"
        property color m3onBackground: "#E0E3E8"
        property color m3surface: "#101417"
        property color m3surfaceDim: "#101417"
        property color m3surfaceBright: "#353A3E"
        property color m3surfaceContainerLowest: "#0A0F12"
        property color m3surfaceContainerLow: "#181C20"
        property color m3surfaceContainer: "#1C2024"
        property color m3surfaceContainerHigh: "#262A2E"
        property color m3surfaceContainerHighest: "#313539"
        property color m3onSurface: "#E0E3E8"
        property color m3surfaceVariant: "#41474D"
        property color m3onSurfaceVariant: "#C1C7CE"
        property color m3inverseSurface: "#E0E3E8"
        property color m3inverseOnSurface: "#2D3135"

        // Outline
        property color m3outline: "#8B9198"
        // readonly property color m3outlineVariant: "#41474D"
        property color m3outlineVariant: "#313539"

        // Shadow & Scrim
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#95CDF7"
    }

    // Computed semantic colors with layer system
    property QtObject colors: QtObject {
        // Subtext
        readonly property color colSubtext: m3colors.m3outline

        // Layer 0 - Base background
        readonly property color colLayer0Base: m3colors.m3background
        readonly property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)
        readonly property color colOnLayer0: m3colors.m3onBackground
        readonly property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0Base, colOnLayer0, 0.9), root.contentTransparency)
        readonly property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0Base, colOnLayer0, 0.8), root.contentTransparency)
        readonly property color colLayer0Border: ColorUtils.mix(m3colors.m3outlineVariant, colLayer0Base, 0.4)

        // Layer 1 - Surface (current Colors.surface)
        readonly property color colLayer1Base: m3colors.m3surfaceContainerLow
        readonly property color colLayer1: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency) : colLayer1Base
        readonly property color colOnLayer1: m3colors.m3onSurfaceVariant
        readonly property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45)
        readonly property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1Base, colOnLayer1, 0.92), root.contentTransparency)
        readonly property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1Base, colOnLayer1, 0.85), root.contentTransparency)

        // Layer 2 - Surface Container (current Colors.surfaceHover)
        readonly property color colLayer2Base: m3colors.m3surfaceContainer
        readonly property color colLayer2: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency) : colLayer2Base
        readonly property color colLayer2Hover: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency) : ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90)
        readonly property color colLayer2Active: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency) : ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80)
        readonly property color colLayer2Disabled: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency) : ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8)
        readonly property color colOnLayer2: m3colors.m3onSurface
        readonly property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4)

        // Layer 3 - Surface Container High (current Colors.surfaceContainerHighest)
        readonly property color colLayer3Base: m3colors.m3surfaceContainerHigh
        readonly property color colLayer3: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency) : colLayer3Base
        readonly property color colLayer3Hover: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency) : ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90)
        readonly property color colLayer3Active: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency) : ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80)
        readonly property color colOnLayer3: m3colors.m3onSurface

        // Layer 4 - Surface Container Highest
        readonly property color colLayer4Base: m3colors.m3surfaceContainerHighest
        readonly property color colLayer4: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency) : colLayer4Base
        readonly property color colLayer4Hover: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency) : ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90)
        readonly property color colLayer4Active: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency) : ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80)
        readonly property color colOnLayer4: m3colors.m3onSurface

        // Primary semantic colors
        readonly property color colPrimary: m3colors.m3primary
        readonly property color colOnPrimary: m3colors.m3onPrimary
        readonly property color colPrimaryHover: ColorUtils.mix(colPrimary, colLayer1Hover, 0.87)
        readonly property color colPrimaryActive: ColorUtils.mix(colPrimary, colLayer1Active, 0.7)
        readonly property color colPrimaryContainer: m3colors.m3primaryContainer
        readonly property color colPrimaryContainerHover: ColorUtils.mix(colPrimaryContainer, colOnPrimaryContainer, 0.9)
        readonly property color colPrimaryContainerActive: ColorUtils.mix(colPrimaryContainer, colOnPrimaryContainer, 0.8)
        readonly property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer

        // Secondary semantic colors
        readonly property color colSecondary: m3colors.m3secondary
        readonly property color colSecondaryHover: ColorUtils.mix(m3colors.m3secondary, colLayer1Hover, 0.85)
        readonly property color colSecondaryActive: ColorUtils.mix(m3colors.m3secondary, colLayer1Active, 0.4)
        readonly property color colOnSecondary: m3colors.m3onSecondary
        readonly property color colSecondaryContainer: m3colors.m3secondaryContainer
        readonly property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        readonly property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.54)
        readonly property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer

        // Tertiary semantic colors
        readonly property color colTertiary: m3colors.m3tertiary
        readonly property color colTertiaryHover: ColorUtils.mix(m3colors.m3tertiary, colLayer1Hover, 0.85)
        readonly property color colTertiaryActive: ColorUtils.mix(m3colors.m3tertiary, colLayer1Active, 0.4)
        readonly property color colOnTertiary: m3colors.m3onTertiary
        readonly property color colTertiaryContainer: m3colors.m3tertiaryContainer
        readonly property color colTertiaryContainerHover: ColorUtils.mix(colTertiaryContainer, colOnTertiaryContainer, 0.90)
        readonly property color colTertiaryContainerActive: ColorUtils.mix(colTertiaryContainer, colLayer1Active, 0.54)
        readonly property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer

        // The bar's ground. Deliberately not colLayer0: the bar carries its own transparency so
        // it can stay near-opaque while the panels go much further.
        readonly property color colBarBackground: ColorUtils.transparentize(colLayer0Base, root.barTransparency)

        // Surface semantic colors (for compatibility)
        readonly property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, root.backgroundTransparency)
        readonly property color colSurfaceContainerLow: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency) : m3colors.m3surfaceContainerLow
        readonly property color colSurfaceContainer: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency) : m3colors.m3surfaceContainer
        readonly property color colSurfaceContainerHigh: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency) : m3colors.m3surfaceContainerHigh
        readonly property color colSurfaceContainerHighest: root.contentTransparency > 0 ? ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerHigh, m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency) : m3colors.m3surfaceContainerHighest
        readonly property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        readonly property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        readonly property color colOnSurface: m3colors.m3onSurface
        readonly property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant

        // Outline
        readonly property color colOutline: m3colors.m3outline
        readonly property color colOutlineVariant: m3colors.m3outlineVariant

        // Error semantic colors
        readonly property color colError: m3colors.m3error
        readonly property color colErrorHover: ColorUtils.mix(m3colors.m3error, colLayer1Hover, 0.85)
        readonly property color colErrorActive: ColorUtils.mix(m3colors.m3error, colLayer1Active, 0.7)
        readonly property color colOnError: m3colors.m3onError
        readonly property color colErrorContainer: m3colors.m3errorContainer
        readonly property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        readonly property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        readonly property color colOnErrorContainer: m3colors.m3onErrorContainer

        // Misc
        readonly property color colTooltip: m3colors.m3inverseSurface
        readonly property color colOnTooltip: m3colors.m3inverseOnSurface
        readonly property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        readonly property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)

        // Status colors (custom, not from matugen)
        readonly property color colBatteryCharging: "#1BCA4B"
        readonly property color colBatteryCritical: "#F60B00"
        readonly property color colPowerButton: "#DD5C82"
        readonly property color colEmptyWorkspace: "#77767b"
        readonly property color colArchBlue: "#0F94D2"
        // The sun on the dashboard's sunrise tile. Fixed rather than taken from the palette:
        // a matugen primary is whatever the wallpaper is, and a green or blue sun stops the
        // graphic saying "sun" at all.
        readonly property color colSun: "#F3B02A"
    }

    // Font configuration
    readonly property QtObject font: QtObject {
        readonly property QtObject family: QtObject {
            readonly property string main: "sans-serif"
            readonly property string monospace: "monospace"
        }
        readonly property QtObject pixelSize: QtObject {
            readonly property int smallest: 10
            readonly property int smaller: 12
            // Material 3 sets both titleSmall and bodyMedium at 14, which is the rich
            // tooltip's whole type scale. It sits between `smaller` and `small` and there is
            // no adjective left for it, hence the name.
            readonly property int smallPlus: 14
            readonly property int small: 15
            readonly property int normal: 16
            readonly property int large: 17
            readonly property int larger: 19
            readonly property int huge: 22
            readonly property int hugeass: 24
        }
    }

    // Rounding values
    readonly property QtObject rounding: QtObject {
        // Material 3 `corner-extra-small`. Well below the rest of this scale on purpose: it
        // is the plain tooltip's radius, and a tooltip is meant to read as a transient
        // annotation rather than as one more of this shell's rounded surfaces.
        readonly property int extraSmall: 4
        readonly property int small: 12
        readonly property int normal: 17
        readonly property int large: 23
        readonly property int full: 9999
    }

    // Size values
    readonly property QtObject sizes: QtObject {
        readonly property real elevationMargin: 10
        readonly property real searchWidthCollapsed: 210
        readonly property real searchWidth: 450
        readonly property real lockAvatar: 64
        readonly property real lockPasswordField: 56
        // Shorter than the field above it on purpose: the fingerprint chip is feedback
        // about a factor already running, not a second thing to type into.
        readonly property real lockFingerprintChip: 44
        readonly property real lockPowerButton: 48
        // The lock composition's own metrics. The clock is display type well outside the UI
        // scale above, so it is sized here rather than squeezed into a name in
        // font.pixelSize. It is sized from the output's width between these bounds, so the
        // same clock reads the same on a 1280 panel as on a 4K one instead of being a fixed
        // slab that only suits the display it was tuned on.
        readonly property real lockClockMin: 120
        readonly property real lockClockMax: 240
        readonly property real lockClockDateMin: 18
        readonly property real lockClockDateMax: 28
        // Scaled with the time above it, not with the date below: the gap's job is to keep
        // the two reading as one block, and that is a proportion of the larger of them.
        readonly property real lockClockGap: 21
        // How far the prompt and the power controls travel as they fade in.
        readonly property real lockRevealRise: 14
        // Shared by the bar's status icons and the lock screen's, so the same reading of
        // the same machine is the same size in both places rather than by coincidence.
        readonly property real statusIcon: 20
    }

    // Animation configuration
    readonly property QtObject animation: QtObject {
        // Material 3 expressive curves, for `easing.bezierCurve` on a BezierSpline easing.
        // The token is the curve alone — each call site still picks its own duration.
        readonly property var expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // radius / colour
        readonly property var expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // width / size bounce

        readonly property QtObject elementMove: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.OutQuad
            readonly property var bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
            readonly property Component numberAnimation: Component {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
            readonly property Component colorAnimation: Component {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
        // A whole composition moving at once, rather than one element resizing: long
        // enough to read as a single travelling shape. Same curve as elementMove, so the
        // two are the same system at two scales.
        readonly property QtObject elementMoveSlow: QtObject {
            readonly property int duration: 400
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
            readonly property Component numberAnimation: Component {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                }
            }
        }
        // A whole composition moving to a new position. Not the emphasized curve the tokens
        // above share: that one's first control point sits at y=0, so the element hesitates
        // before it moves — invisible on a button, plainly a lag on a shape the size of a
        // lock screen clock. This one leaves immediately and coasts in.
        readonly property QtObject compositionTravel: QtObject {
            readonly property int duration: 380
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: [0.2, 0.8, 0.2, 1.0, 1, 1]
        }
        // Something arriving in place rather than travelling to it, over a composition that
        // is still settling. Deliberately quicker than compositionTravel: without the
        // contrast the two read as one slab moving at a single rate.
        readonly property QtObject compositionAppear: QtObject {
            readonly property int duration: 180
            readonly property int riseDuration: 240
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
        }
        readonly property QtObject elementMoveFast: QtObject {
            readonly property int duration: 100
            readonly property Component colorAnimation: Component {
                ColorAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
            readonly property Component numberAnimation: Component {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
