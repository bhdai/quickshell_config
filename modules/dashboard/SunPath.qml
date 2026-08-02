import QtQuick
import qs.modules.common
import qs.modules.common.functions
import "weather_tile_geometry.js" as TileGeometry

/**
 * The sun tile's landscape, painted under the whole tile rather than inside its padding: sky
 * over ground, one ridge crossing both, and the sun sitting on the ridge. Sized to the whole
 * tile, so `cornerRadius` has to be the tile's own radius — the ground runs into the corners
 * and is clipped by them.
 *
 * The colours are read here rather than passed in: there are six of them, and every one is a
 * fixed role, so a caller could only ever hand back what this would have picked anyway. Each
 * is a property so that a palette change raises a signal and repaints.
 */
Canvas {
    id: root

    // A weather_tile_geometry.js sunTrack(): 0 at sunrise, 1 at sunset, a little past both.
    property real progress: 0
    property real cornerRadius: 0

    readonly property color skyColor: Appearance.colors.colLayer1
    readonly property color ridgeColor: Appearance.colors.colSecondaryContainer
    // Translucent, and that is the whole point: the ground is a layer over the landscape
    // rather than a second landscape, so the ridge stays visibly on its way down behind it.
    // Being a tone above the sky, it lifts the ground's background as it dims the ridge.
    readonly property color groundColor: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.25)
    readonly property color horizonColor: Appearance.colors.colOutlineVariant
    readonly property color sunColor: Appearance.colors.colSun

    onProgressChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onSkyColorChanged: requestPaint()
    onGroundColorChanged: requestPaint()
    onRidgeColorChanged: requestPaint()
    onHorizonColorChanged: requestPaint()
    onSunColorChanged: requestPaint()

    Behavior on progress {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutQuad
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        // Clears the clip region as well as the path — both are set below on every pass and
        // would otherwise intersect with themselves across repaints.
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.beginPath();
        ctx.roundedRect(0, 0, width, height, root.cornerRadius, root.cornerRadius);
        ctx.clip();

        // Terrain first and whole, then the ground laid over its lower half. Painting the
        // two halves separately would put a seam on the horizon; this way the same shape
        // simply passes under it.
        const ridge = TileGeometry.sunPath(width, height, TileGeometry.SUN_SAMPLES);
        ctx.beginPath();
        ctx.moveTo(ridge[0].x, ridge[0].y);
        for (let i = 1; i < ridge.length; i++)
            ctx.lineTo(ridge[i].x, ridge[i].y);
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();

        ctx.fillStyle = root.ridgeColor;
        ctx.fill();

        const horizon = TileGeometry.sunHorizon(height);
        ctx.fillStyle = root.groundColor;
        ctx.fillRect(0, horizon, width, height - horizon);

        ctx.fillStyle = root.horizonColor;
        ctx.fillRect(0, horizon, width, 1);

        const sun = TileGeometry.sunMarker(width, height, root.progress);
        const disc = TileGeometry.scallopedCircle(sun.x, sun.y, TileGeometry.SUN_MARKER_RADIUS, TileGeometry.SUN_MARKER_LOBES, TileGeometry.SUN_MARKER_SCALLOP, TileGeometry.SUN_MARKER_SAMPLES);
        ctx.beginPath();
        ctx.moveTo(disc[0].x, disc[0].y);
        for (let i = 1; i < disc.length; i++)
            ctx.lineTo(disc[i].x, disc[i].y);
        ctx.closePath();

        // Stroked before it is filled, so the sky-toned ring reads as a gap around the sun
        // and the fill takes back the inner half of it. Without it the sun disappears into
        // the ridge whenever it is sitting on it.
        ctx.lineWidth = 3;
        ctx.strokeStyle = root.skyColor;
        ctx.stroke();
        ctx.fillStyle = root.sunColor;
        ctx.fill();
    }
}
