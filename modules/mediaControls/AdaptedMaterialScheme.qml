import QtQuick
import "." as MediaControls

QtObject {
    id: root
    required property color sourceColor
    readonly property bool colorIsDark: sourceColor.hslLightness < 0.5

    // base colors
    property color baseLayer0: "#1e1e1e"
    property color baseLayer1: "#2d2d2d"
    property color baseOnLayer0: "#ffffff"
    property color baseOnLayer1: "#ffffff"
    property color baseSubtext: "#aaaaaa"
    property color basePrimary: "#90caf9"
    property color baseSecondaryContainer: "#3d3d3d"
    property color baseOnPrimary: "#000000"
    property color baseOnSecondaryContainer: "#ffffff"

    // adapted colors - blend with source color
    property color colLayer0: MediaControls.ColorUtils.mix(baseLayer0, sourceColor, colorIsDark ? 0.6 : 0.5)
    property color colLayer1: MediaControls.ColorUtils.mix(baseLayer1, sourceColor, 0.5)
    property color colOnLayer0: MediaControls.ColorUtils.mix(baseOnLayer0, sourceColor, 0.5)
    property color colOnLayer1: MediaControls.ColorUtils.mix(baseOnLayer1, sourceColor, 0.5)
    property color colSubtext: MediaControls.ColorUtils.mix(baseSubtext, sourceColor, 0.5)

    property color colPrimary: MediaControls.ColorUtils.mix(basePrimary, sourceColor, 0.5)
    property color colPrimaryHover: MediaControls.ColorUtils.lighten(colPrimary, 0.1)
    property color colPrimaryActive: MediaControls.ColorUtils.lighten(colPrimary, 0.2)

    property color colSecondaryContainer: MediaControls.ColorUtils.mix(baseSecondaryContainer, sourceColor, 0.15)
    property color colSecondaryContainerHover: MediaControls.ColorUtils.lighten(colSecondaryContainer, 0.1)
    property color colSecondaryContainerActive: MediaControls.ColorUtils.lighten(colSecondaryContainer, 0.2)

    property color colOnPrimary: MediaControls.ColorUtils.mix(baseOnPrimary, sourceColor, 0.5)
    property color colOnSecondaryContainer: MediaControls.ColorUtils.mix(baseOnSecondaryContainer, sourceColor, 0.5)
}
