pragma Singleton
import QtQuick
import Quickshell

/**
 * LauncherAppearance - Compatibility layer mapping our Colors to dots-hyprland's Appearance API
 * This allows us to use dots-hyprland UI components with minimal changes
 */
Singleton {
    id: root

    // Material 3 color mappings
    readonly property QtObject m3colors: QtObject {
        readonly property bool darkmode: true
        readonly property color m3surface: "#1C2024"
        readonly property color m3surfaceContainer: "#1C2024"
        readonly property color m3onSurface: "#E0E3E8"
        readonly property color m3primary: "#95CDF7"
        readonly property color m3onPrimary: "#00344D"
        readonly property color m3primaryContainer: "#384956"
        readonly property color m3onPrimaryContainer: "#D3E5F5"
        readonly property color m3outline: "#8B9198"
        readonly property color m3outlineVariant: "#242A2E"
    }

    // Semantic color mappings used by SearchWidget/SearchItem
    readonly property QtObject colors: QtObject {
        readonly property color colBackgroundSurfaceContainer: "#1C2024"
        readonly property color colOutlineVariant: "#242A2E"
        readonly property color colPrimaryContainer: "#384956"
        readonly property color colPrimaryContainerActive: "#262A2E"
        readonly property color colOnPrimaryContainer: "#E0E3E8"
        readonly property color colSubtext: "#C7C7C7"
        readonly property color colPrimary: "#95CDF7"
        readonly property color colOnPrimary: "#00344D"
        readonly property color colSecondaryContainerHover: "#262A2E"
        readonly property color colSecondaryContainerActive: "#262A2E"
        readonly property color colOnSurfaceVariant: "#C7C7C7"
        readonly property color colSurfaceContainerHigh: "#313539"
        readonly property color colPrimaryHover: "#B0DCF9"
    }

    // Font configuration
    readonly property QtObject font: QtObject {
        readonly property QtObject family: QtObject {
            readonly property string main: "sans-serif"
            readonly property string monospace: "monospace"
        }
        readonly property QtObject pixelSize: QtObject {
            readonly property int smaller: 12
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
        readonly property int small: 12
        readonly property int normal: 17
        readonly property int large: 23
        readonly property int full: 9999
    }

    // Size values for the search widget
    readonly property QtObject sizes: QtObject {
        readonly property real searchWidthCollapsed: 210
        readonly property real searchWidth: 450
        readonly property real elevationMargin: 10
    }

    // Animation configuration
    readonly property QtObject animation: QtObject {
        readonly property QtObject elementMove: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.OutQuad
            readonly property var bezierCurve: [0.2, 0.0, 0.0, 1.0]
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
        readonly property QtObject elementMoveFast: QtObject {
            readonly property int duration: 100
            readonly property Component colorAnimation: Component {
                ColorAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
