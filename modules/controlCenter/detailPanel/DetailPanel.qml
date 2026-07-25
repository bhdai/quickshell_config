import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * The chrome both control-center detail panels wear: centered title and subtitle, a short
 * centered indicator, an adapter switch row, and a Done footer. The panel's own list goes in
 * the default slot, which is an Item — anchor its content to `parent`.
 *
 * The switch is two-way through the owner: `switchChecked` reads the adapter and
 * `switchToggled()` asks the owner to flip it, so nothing here caches adapter state.
 */
Rectangle {
    id: root

    property string title
    property string subtitle
    property bool scanning: false
    property string switchLabel
    property bool switchChecked: false

    default property alias content: contentArea.data

    signal switchToggled
    signal done

    color: Appearance.colors.colLayer0
    radius: 20
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.larger
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.subtitle
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        ScanIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.width * 0.44
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            scanning: root.scanning
        }

        SwitchRow {
            Layout.fillWidth: true
            label: root.switchLabel
            checked: root.switchChecked
            onToggled: root.switchToggled()
        }

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Item {
                Layout.fillWidth: true
            }

            RippleButton {
                id: doneButton

                implicitHeight: 40
                implicitWidth: 90
                padding: 0
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive

                // The Control sizes contentItem to the whole button, so the label centres
                // itself inside that box rather than being centred as a box of its own.
                contentItem: Text {
                    text: "Done"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.bold: true
                    color: Appearance.colors.colOnPrimary
                }

                onClicked: root.done()
            }
        }
    }
}
