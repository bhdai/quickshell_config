import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "dashboard_metrics.js" as Metrics

/**
 * The Performance destination's inner card: the dashboard's existing card grammar — the
 * layer-1 surface at the small radius — under a filled symbol and a demibold title.
 *
 * Title and symbol keep their ordinary colours whatever the card is reporting. A reading in
 * warning state recolours itself and nothing else; a card that went red as a whole would say
 * the machine is in trouble when one of four numbers is.
 */
Rectangle {
    id: root

    property string symbol
    property string title
    default property alias content: contentContainer.data

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small

    Item {
        anchors.fill: parent
        anchors.margins: Metrics.PERFORMANCE_CARD_PAD

        Row {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            MaterialSymbol {
                text: root.symbol
                iconSize: 24
                fill: 1
                color: Appearance.colors.colOnLayer2
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.title
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            id: contentContainer

            anchors.top: header.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
    }
}
