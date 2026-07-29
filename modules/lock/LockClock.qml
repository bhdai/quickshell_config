import QtQuick
import qs.modules.common
import qs.services

/**
 * The clock and date, as one element. The reveal shrinks it with `scale` rather than by
 * restyling the type, so it travels to the upper quarter as a single shape instead of
 * re-laying out on every animation frame.
 *
 * The caller must hand it `availableWidth`: this is display type sized from the output it
 * is drawn on, and a Column has no width of its own to read that from.
 */
Column {
    id: root

    // The width of the output this clock is composed on, not of the clock itself.
    property real availableWidth: 0

    // The prototype's `clamp(120px, 18vw, 300px)` and `clamp(18px, 1.6vw, 28px)`. The
    // fractions live here rather than in Appearance because they are this composition's
    // proportions, the way the surface's vertical fractions are its own.
    readonly property real timeFraction: 0.18
    readonly property real dateFraction: 0.016

    readonly property real timeSize: Math.max(Appearance.sizes.lockClockMin, Math.min(root.availableWidth * root.timeFraction, Appearance.sizes.lockClockMax))
    readonly property real dateSize: Math.max(Appearance.sizes.lockClockDateMin, Math.min(root.availableWidth * root.dateFraction, Appearance.sizes.lockClockDateMax))

    spacing: Appearance.sizes.lockClockGap

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Time.hoursMinutes
        color: Appearance.colors.colOnLayer0
        font.family: Appearance.font.family.main
        font.pixelSize: root.timeSize
        font.weight: Font.Light

        // Display type, not large body text. The negative tracking is what pulls the digits
        // into one deliberate shape at this size, and the tight leading is what keeps the
        // date under the time rather than a line's worth of air away from it. Both are
        // proportions of the size, so an output of any width carries them with it.
        font.letterSpacing: -0.09 * root.timeSize
        lineHeight: 0.86

        // "hh:mm" holds its character count, but a proportional font gives each digit its
        // own advance — so the string's width, and with it a centred clock, would move every
        // minute. Tabular figures give every digit the same cell.
        font.features: ({
            "tnum": 1
        })

        // Glyph outlines on the GPU rather than the default distance fields. A distance
        // field is cached at one base size — tens of pixels — and scaled to whatever the
        // text asks for, which at display size reads as a blown-up bitmap rather than as
        // type, and the reveal's `scale` puts it at a third size again. Curves are
        // resolution independent, so this stays sharp at every size it is drawn at.
        renderType: Text.CurveRendering
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(Time.date, "dddd, d MMMM")
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Appearance.font.family.main
        font.pixelSize: root.dateSize
    }
}
