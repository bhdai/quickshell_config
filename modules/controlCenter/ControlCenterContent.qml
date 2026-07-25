import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell.Bluetooth
import "./quickToggles/"
import "./notifications/"
import "./wifiNetwork/"
import "./bluetoothDevice/"

ColumnLayout {
    id: root
    spacing: 10

    implicitWidth: 420

    property real availableHeight: 780 // default fallback

    property int radius: 20
    property int margins: 15
    property int notificationCount: Notifications.list.length

    readonly property real maxNotificationHeight: availableHeight - controlPannel.height - spacing // - margins * 2

    property alias topWindow: controlPannel
    property alias bottomWindow: contentLoader

    // Which detail panel the bottom container is showing: "wifi", "bluetooth", or "" for the
    // notification list. One property rather than a flag per panel — with two flags, swapping
    // panels takes two writes, and the binding below re-evaluates between them, so the Loader
    // built and tore down the notification list on the way from one panel to the other.
    property string openPanel: ""

    onOpenPanelChanged: {
        if (openPanel !== "bluetooth" && Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.discovering = false;
    }

    Rectangle {
        id: controlPannel

        // implicitHeight, not height: a ColumnLayout assigns its children's `height` itself, so
        // binding it here left the layout squeezing the card to its implicit zero on every
        // relayout and the binding snapping it back — a visible jump each time a panel opened.
        implicitHeight: mainLayout.implicitHeight + root.margins * 2
        // A ColumnLayout shrinks every child toward its minimum when the children want more
        // room than there is, and Layout.fillHeight only governs growth — so without a floor
        // here the card lost its share of the deficit a detail panel opens, while the layout
        // inside it stayed anchored to the top and spilled out of the shrinking background.
        // The card is fixed chrome; the detail panel below scrolls, so it absorbs the deficit.
        Layout.minimumHeight: implicitHeight

        radius: root.radius
        color: Appearance.m3colors.m3background
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
        Layout.fillWidth: true

        ColumnLayout {
            id: mainLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.margins
            spacing: 10

            ButtonGroup {
                Layout.fillWidth: true
                spacing: 10

                NetworkToggle {
                    onOpenWifiPanel: {
                        Network.enableWifi();
                        Network.rescanWifi();
                        root.openPanel = "wifi";
                    }
                }

                BluetoothToggle {
                    // Neither the adapter nor discovery is forced on here: the panel's own
                    // "Use Bluetooth" switch owns the adapter, and its "Pair new device" row
                    // owns discovery — which the scan indicator would otherwise show forever.
                    onOpenBluetoothPanel: root.openPanel = "bluetooth"
                }
            }

            ButtonGroup {
                Layout.fillWidth: true
                spacing: 10

                PowerProfile {}
                CloudflareWarp {}
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

    // Bottom container: WiFi panel, Bluetooth panel, or notifications

    Loader {
        id: contentLoader
        Layout.fillWidth: true
        Layout.fillHeight: root.openPanel !== ""
        sourceComponent: {
            if (root.openPanel === "wifi")
                return wifiPanelComponent;
            if (root.openPanel === "bluetooth")
                return bluetoothPanelComponent;
            return notificationPanelComponent;
        }
    }

    Component {
        id: wifiPanelComponent

        WiFiPanel {
            onClosePanel: {
                root.openPanel = "";
            }
        }
    }

    Component {
        id: bluetoothPanelComponent

        BluetoothPanel {
            onClosePanel: {
                root.openPanel = "";
            }
        }
    }

    Component {
        id: notificationPanelComponent

        Rectangle {
            id: notificationsPannel
            color: Appearance.m3colors.m3background
            radius: root.radius

            property bool isInitialized: false

            implicitHeight: Math.min(notifColumn.implicitHeight + root.margins * 2, root.maxNotificationHeight)

            height: implicitHeight
            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant
            visible: root.notificationCount > 0

            Component.onCompleted: {
                initTimer.start();
            }

            Timer {
                id: initTimer
                interval: 1
                repeat: false
                onTriggered: {
                    notificationsPannel.isInitialized = true;
                }
            }

            Behavior on implicitHeight {
                enabled: isInitialized
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
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.3
                }

                NotificationList {
                    id: list
                    headerAndMarginHeight: notifHeader.implicitHeight + root.margins * 2 + separator.implicitHeight + (notifColumn.spacing * 2)
                    maxPanelHeight: root.maxNotificationHeight
                }
            }
        }
    }

    // Packs a short notification list up against the card. It must stop filling once a detail
    // panel opens, or it splits the leftover space with the panel and each panel settles at a
    // height of its own — so swapping one panel for another moves the bottom edge. With only
    // the panel filling, every panel gets exactly the space the card leaves, whatever it asked
    // for, and a swap changes nothing outside the panel.
    Item {
        Layout.fillHeight: root.openPanel === ""
    }
}
