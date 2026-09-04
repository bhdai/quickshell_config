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

    // Everything the card leaves. A panel that wants more than this scrolls inside it — the
    // window is a fixed layer surface and cannot grow to meet a taller panel.
    //
    // The card's implicit height, not its laid-out one: the panel below is sized from this and
    // the layout is sized from the panel, so reading back a height the layout had just assigned
    // would let one relayout feed the next.
    readonly property real maxPanelHeight: availableHeight - controlPannel.implicitHeight - spacing

    property alias topWindow: controlPannel
    property alias bottomWindow: contentLoader

    // The whole content is rebuilt every time the control center opens, and the container below
    // reads its height off a Loader that has no item yet on the first pass — so the first height
    // it settles on arrives as a jump from zero. That jump is the panel appearing, not the panel
    // moving, and animating it unrolls the notification list from nothing on every open.
    //
    // A timer rather than Qt.callLater: callLater still runs inside the turn that lays the
    // content out, so the flag was already set when that first height landed.
    property bool placed: false

    Timer {
        interval: 1
        running: true
        onTriggered: root.placed = true
    }

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
        color: Appearance.colors.colLayer0
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
        // The panel names its own height and the container follows it. Both detail panels ask
        // for the whole of `maxPanelHeight` and so are fixed; the notification list asks for
        // what it holds. Deliberately not filled: a filled loader gives every panel the same
        // leftover space, which is the one thing the notification list must not get.
        //
        // Only the bottom edge moves. The card is above this in the column and never resizes,
        // so this container's top edge — and the gap above it — is the same in every state.
        Layout.preferredHeight: item?.implicitHeight ?? 0

        // One animation for the whole swap, here rather than inside each panel — two panels
        // animating their own heights into a container that animates again reads as a single
        // sluggish move with a soft landing.
        Behavior on Layout.preferredHeight {
            enabled: root.placed
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

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
            maxPanelHeight: root.maxPanelHeight
            onClosePanel: {
                root.openPanel = "";
            }
        }
    }

    Component {
        id: bluetoothPanelComponent

        BluetoothPanel {
            maxPanelHeight: root.maxPanelHeight
            onClosePanel: {
                root.openPanel = "";
            }
        }
    }

    Component {
        id: notificationPanelComponent

        Rectangle {
            id: notificationsPannel
            color: Appearance.colors.colLayer0
            radius: root.radius

            // Zero when there is nothing to show, so an empty list leaves no invisible strip
            // below the card holding the bottom edge down — and taking clicks, since the
            // window's input mask is cut from this item's geometry.
            implicitHeight: visible ? Math.min(notifColumn.implicitHeight + root.margins * 2, root.maxPanelHeight) : 0

            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant
            visible: root.notificationCount > 0

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
                    maxPanelHeight: root.maxPanelHeight
                }
            }
        }
    }

    // Eats whatever height the card and the panel do not use. Without something here to take
    // it, a ColumnLayout hands the surplus to the rows themselves and centres them in it, so a
    // short notification list pushed the card down the screen and dragged the panel's top edge
    // with it — the card has to sit in the same place whatever is below it.
    Item {
        Layout.fillHeight: true
    }
}
