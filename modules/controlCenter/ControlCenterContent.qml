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

    property real availableHeight: 780 // default fallback

    property int radius: 20
    property int margins: 15
    property int notificationCount: Notifications.list.length

    readonly property real maxNotificationHeight: availableHeight - controlPannel.height - spacing - margins * 2

    property alias topWindow: controlPannel
    property alias bottomWindow: notificationsPannel

    Rectangle {
        id: controlPannel

        height: mainLayout.implicitHeight + root.margins * 2

        radius: root.radius
        color: Colors.background
        Layout.fillWidth: true

        ColumnLayout {
            id: mainLayout
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
                // Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: 10

                PowerProfile {}
                NightLight {}
                IdleInhibitor {}
                GameMode {}
                SilentNotification {}
                MicToggle {}
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

        implicitHeight: Math.min(notifColumn.implicitHeight + root.margins * 2, root.maxNotificationHeight)
        height: implicitHeight

        visible: root.notificationCount > 0

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }

        ColumnLayout {
            id: notifColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.margins
            spacing: 5

            NotificationHeader {
                id: notifHeader
            }

            Rectangle {
                id: separator
                implicitHeight: 1
                Layout.fillWidth: true
                color: Colors.text
                opacity: 0.3
            }

            NotificationList {
                id: list
                // calculate the non-scrollable overhead
                headerAndMarginHeight: notifHeader.implicitHeight + root.margins * 2 + separator.implicitHeight + (notifColumn.spacing * 2)
                maxPanelHeight: root.maxNotificationHeight
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
