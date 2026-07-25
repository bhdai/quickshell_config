import qs.modules.common
import QtQuick
import QtQuick.Layouts

/**
 * A read-only row in a detail subpage's CardGroup: label on the left, value on the right.
 *
 * A Rectangle rather than a wrapper so a CardGroup can shape its corners directly — the group
 * requires the four per-corner radius properties, which a Rectangle has natively.
 *
 * Both texts fill, so a long value (an IPv6 address, a MAC) takes the width it needs and elides
 * only once the row genuinely runs out, rather than overflowing the card.
 */
Rectangle {
    id: root

    property string label
    property string value

    implicitHeight: 56
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Text {
            text: root.label
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.value
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
