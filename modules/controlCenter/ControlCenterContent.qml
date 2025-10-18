import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "./quickToggles/"
import "./notifications/"

ColumnLayout {
    id: root
    spacing: 10

    implicitWidth: 420

    property int radius: 20
    property real controlPanelHeight: 250
    property int margins: 15
    property int notificationCount: Notifications.list.length
    readonly property real maxNotificationHeight: parent.height - controlPannel.height - root.spacing - anchors.margins
    property alias topWindow: controlPannel
    property alias bottomWindow: notificationsPannel

    Rectangle {
        id: controlPannel

        // height: root.controlPanelHeight
        height: mainLayout.implicitHeight + root.margins * 2

        radius: root.radius
        color: Colors.background
        Layout.fillWidth: true

        ColumnLayout {
            id: mainLayout
            // anchors.fill: parent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.margins
            spacing: 10

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
                spacing: 20

                AudioSlider {}
                BrightnessSlider {}
            }
        }
    }

    Rectangle {
        id: notificationsPannel
        color: Colors.background
        radius: root.radius

        Layout.fillWidth: true

        height: list.panelHeight

        visible: root.notificationCount > 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.margins
            spacing: 5

            NotificationHeader {
                id: notifHeader
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                height: 1
                Layout.fillWidth: true
                color: Colors.text
                opacity: 0.2
            }

            NotificationList {
                id: list
                headerAndMarginHeight: notifHeader.implicitHeight + root.margins * 2 + 12
                maxPanelHeight: root.maxNotificationHeight
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
