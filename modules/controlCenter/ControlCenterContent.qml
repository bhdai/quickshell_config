import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import "./quickToggles/"

Rectangle {
    id: root

    implicitWidth: 420

    radius: 20
    color: Colors.background

    ColumnLayout {
        id: mainLayout
        // anchors.fill: parent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 15
        spacing: 15

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NetworkToggle {
                Layout.fillWidth: true
            }

            BluetoothToggle {
                Layout.fillWidth: true
            }
        }

        ButtonGroup {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            padding: 5

            PowerProfile {}
            NightLight {}
            IdleInhibitor {}
            GameMode {}
            EasyEffectsToggle {}
            CloudflareWrap {}
        }

        ColumnLayout {
            id: slidersLayout
            Layout.fillWidth: true
            spacing: 15

            AudioSlider {}
            BrightnessSlider {}
        }
    }
}
