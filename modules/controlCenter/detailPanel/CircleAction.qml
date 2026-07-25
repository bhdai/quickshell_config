import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * A detail subpage's primary action: a round icon button with its label beneath. Reserved for
 * actions that take effect immediately — anything that opens another surface belongs in the
 * page's header instead, where it does not read as one of these.
 */
ColumnLayout {
    id: root

    property string symbol
    property string label

    signal triggered

    spacing: 6

    RippleButton {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 56
        implicitHeight: 56
        padding: 0
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colPrimary

        onClicked: root.triggered()

        contentItem: MaterialSymbol {
            text: root.symbol
            iconSize: 24
            color: Appearance.colors.colOnSecondaryContainer
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.label
        color: Appearance.colors.colOnLayer0
        font.pixelSize: Appearance.font.pixelSize.smaller
    }
}
