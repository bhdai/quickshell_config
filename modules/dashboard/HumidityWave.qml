import QtQuick
import "weather_tile_geometry.js" as TileGeometry

/**
 * The humidity tile's water: the tile fills to the reading, and the top of the fill is the
 * Material 3 wave motif. Sized to the whole tile, so `cornerRadius` has to be the tile's own
 * radius — the fill is clipped to it rather than inset away from it.
 */
Canvas {
    id: root

    // Fill fraction measured up from the bottom. TileGeometry.waterLevel() maps a reading here.
    property real level: 0
    property real cornerRadius: 0
    property color color: "transparent"

    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()

    Behavior on level {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutQuad
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        // Clears the clip region as well as the path — it is set below on every pass and
        // would otherwise intersect with itself across repaints.
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        if (root.level <= 0)
            return;

        ctx.beginPath();
        ctx.roundedRect(0, 0, width, height, root.cornerRadius, root.cornerRadius);
        ctx.clip();

        const points = TileGeometry.waveLine(width, height, root.level, TileGeometry.WAVE_AMPLITUDE, TileGeometry.waveWavelength(width), TileGeometry.WAVE_PHASE, TileGeometry.WAVE_SAMPLES);

        ctx.fillStyle = root.color;
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (let i = 1; i < points.length; i++)
            ctx.lineTo(points[i].x, points[i].y);
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fill();
    }
}
