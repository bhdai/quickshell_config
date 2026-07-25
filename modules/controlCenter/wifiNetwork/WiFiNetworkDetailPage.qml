import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * The connected network's details, pushed in over the Wi-Fi panel by its gear. The page exists
 * only for the network the machine is actually on: most rows below the header describe a live
 * connection, so the panel closes the page as soon as that connection ends rather than leaving
 * it describing a connection nobody has.
 *
 * `network` is null while no subpage is open and goes null if the access point leaves the scan,
 * so every read of it is guarded. The profile-side rows come from `Network.connectionDetails`,
 * which the page refreshes on the way in — nothing polls for a page nobody is looking at.
 */
Rectangle {
    id: root

    property WifiAccessPoint network

    readonly property var details: Network.connectionDetails
    readonly property string ssid: root.network?.ssid ?? ""

    signal back

    color: Appearance.colors.colLayer0
    radius: 20
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    onVisibleChanged: {
        if (root.visible && root.ssid)
            Network.refreshConnectionDetails(root.ssid);
    }

    // A reconnect or an address change replaces everything below the header, and the page is
    // already open when it happens. A vanished connection is not refreshed: the panel is closing
    // the page, and re-reading would blank its rows on the way out.
    Connections {
        target: Network

        function onActiveChanged() {
            if (root.visible && Network.active && root.ssid)
                Network.refreshConnectionDetails(root.ssid);
        }
    }

    // The subpage only covers the panel visually: a Rectangle consumes no input, so without
    // this the panel's rows underneath still take the hover (and the click). Declared first,
    // so the page's own controls sit above it.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: Qt.ArrowCursor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                padding: 0
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colPrimary

                onClicked: root.back()

                contentItem: MaterialSymbol {
                    text: "arrow_back"
                    iconSize: 22
                    color: Appearance.colors.colOnLayer0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Network details"
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.large
                font.bold: true
                elide: Text.ElideRight
            }

            // Everything this page cannot express — static addressing, DNS overrides, 802.1X —
            // stays NetworkManager's own editor. It opens a window rather than acting in place,
            // which is why it sits up here instead of among the circle actions.
            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                padding: 0
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colPrimary

                onClicked: Network.openConnectionEditor(root.ssid)

                contentItem: MaterialSymbol {
                    text: "edit"
                    iconSize: 22
                    color: Appearance.colors.colOnLayer0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Everything below the navigation bar scrolls, identity and actions included. Pinning
        // those would spend more than half the panel on a header and leave the rows — which are
        // what the page is for — reading through a slot a few rows tall.
        Flickable {
            id: rowsView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: rows

                // The Flickable's own width, not `parent.width`: children are parented into its
                // contentItem, which carries no width of its own and would collapse the rows.
                width: rowsView.width
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    implicitWidth: 88
                    implicitHeight: 88
                    radius: width / 2
                    color: Appearance.colors.colSecondaryContainer

                    CustomIcon {
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        source: Network.networkSymbol(root.network?.strength ?? 0)
                        colorize: true
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: root.ssid
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: Network.connectionStatusLine(root.details)
                    visible: text.length > 0
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 4
                    spacing: 32

                    CircleAction {
                        symbol: "delete"
                        label: "Forget"
                        // Deleting the profile ends the connection, this page's whole subject.
                        onTriggered: {
                            Network.forgetWifiNetwork(root.ssid);
                            root.back();
                        }
                    }

                    CircleAction {
                        symbol: "wifi_off"
                        label: "Disconnect"
                        onTriggered: {
                            Network.disconnectWifiNetwork();
                            root.back();
                        }
                    }
                }

                CardGroup {
                    Layout.fillWidth: true

                    SwitchRow {
                        Layout.fillWidth: true
                        label: "Connect automatically"
                        checked: root.details.autoconnect ?? false
                        onToggled: Network.setAutoconnect(root.ssid, !(root.details.autoconnect ?? false))
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "Signal strength"
                        value: Network.signalLabel(root.network?.strength ?? 0)
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "Frequency"
                        value: Network.frequencyLabel(root.network?.frequency ?? 0)
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "Security"
                        value: Network.securityLabel(root.network?.security ?? "")
                    }

                    // On a mesh or a repeater the SSID is shared by several radios, and this is
                    // the only thing that says which one the machine actually landed on.
                    InfoRow {
                        Layout.fillWidth: true
                        label: "Access point"
                        value: root.network?.bssid ?? ""
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "Network usage"
                        value: Network.meteredLabel(root.details.metered ?? "")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 4
                    text: "Network details"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.bold: true
                }

                CardGroup {
                    Layout.fillWidth: true

                    InfoRow {
                        Layout.fillWidth: true
                        label: "IP address"
                        value: root.details.ipv4 ?? ""
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "Gateway"
                        value: root.details.gateway ?? ""
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "Subnet mask"
                        value: root.details.netmask ?? ""
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "DNS"
                        value: (root.details.dns ?? []).join(", ")
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "IPv6 address"
                        value: root.details.ipv6 ?? ""
                        visible: value.length > 0
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        label: "MAC address"
                        value: root.details.mac ?? ""
                        visible: value.length > 0
                    }
                }
            }
        }
    }
}
