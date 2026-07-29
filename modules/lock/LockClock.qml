import QtQuick
import qs.modules.common
import qs.services

/**
 * The clock and date, as one element. The reveal shrinks it with `scale` rather than by
 * restyling the type, so it travels to the upper quarter as a single shape instead of
 * re-laying out on every animation frame.
 */
Column {
    spacing: Appearance.font.pixelSize.hugeass

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Time.hoursMinutes
        color: Appearance.colors.colOnLayer0
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.hugeass * 8
        font.weight: Font.Light
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(Time.date, "dddd, d MMMM")
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.hugeass
    }
}
