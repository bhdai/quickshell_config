import QtQuick
import qs.modules.common
import qs.services

/**
 * The clock and date, as one element. The reveal shrinks it with `scale` rather than by
 * restyling the type, so it travels to the upper quarter as a single shape instead of
 * re-laying out on every animation frame.
 */
Column {
    spacing: Appearance.sizes.lockClockGap

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Time.hoursMinutes
        color: Appearance.colors.colOnLayer0
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.sizes.lockClock
        font.weight: Font.Light

        // Display type, not large body text. The negative tracking is what pulls the digits
        // into one deliberate shape at this size, and the tight leading is what keeps the
        // date under the time rather than a line's worth of air away from it. Both are
        // proportions of the size, so retuning the size carries them with it.
        font.letterSpacing: -0.09 * Appearance.sizes.lockClock
        lineHeight: 0.86

        // "hh:mm" holds its character count, but a proportional font gives each digit its
        // own advance — so the string's width, and with it a centred clock, would move every
        // minute. Tabular figures give every digit the same cell.
        font.features: ({
            "tnum": 1
        })
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(Time.date, "dddd, d MMMM")
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.sizes.lockClockDate
    }
}
