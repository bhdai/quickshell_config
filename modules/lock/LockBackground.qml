import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * The wallpaper layer: the desktop's own image, under a strong blur and a neutral scrim.
 *
 * Nothing in here can make the lock transparent. The surface below paints an opaque
 * themed colour and this draws on top of it, so a renamed file, a decode failure and an
 * image that has not finished loading all degrade to that themed solid surface. That is
 * also what makes loading the image asynchronously safe.
 */
Item {
    id: root

    // The lock's whole knowledge of where the wallpaper is: one property, kept in sync
    // with hyprpaper's by hand. Deliberately not discovered — parsing another tool's
    // config would couple this to a tool that is meant to be replaced. When the wallpaper
    // service arrives it becomes this property's source and no other lock code changes.
    property url source: `${Directories.home}/Pictures/wall/leaves.jpg`

    Image {
        id: wallpaper

        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        cache: false

        // A multi-megabyte photo must not hold the lock off the screen: the decode runs
        // off the render thread and is pinned to the output's size rather than the file's.
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height

        // Far past the prototype's ~14 px at 1600x900: the photo is texture behind the
        // composition, not a picture with a clock on it. blurMax is the radius `blur` is a
        // fraction of, and 64 is MultiEffect's ceiling for it — blurMultiplier is what
        // reaches beyond that, by widening the sample offsets rather than by adding
        // downscale levels, so pushing it much further trades the smoothness for blocking.
        layer.enabled: true
        layer.effect: MultiEffect {
            source: wallpaper
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            blurMultiplier: 0.5
            saturation: -0.28
        }
    }

    // Neutral black with no matugen tint. The palette is generated *from* this image, so
    // tinting the scrim toward the palette would recolour the photo toward itself.
    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.7)
    }
}
