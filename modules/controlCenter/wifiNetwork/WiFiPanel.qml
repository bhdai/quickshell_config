import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import Quickshell

Item {
    id: root

    signal closePanel

    // How much of the scan the list shows before the See-all chevron; the strongest networks
    // are all a user normally wants, and the tail of far-away access points is long.
    readonly property int collapsedCount: 5
    readonly property var sortedNetworks: Network.sortWifiNetworks(Network.wifiNetworks)
    property bool showAll: false
    // The network whose subpage is showing. Held while the subpage slides back out so its
    // content does not blank mid-animation; the scan dropping the access point nulls it.
    property WifiAccessPoint detailNetwork: null
    property bool detailOpen: false

    implicitHeight: 720
    // The subpage slides in from beyond the right edge.
    clip: true

    onDetailNetworkChanged: {
        if (!detailNetwork)
            detailOpen = false;
    }

    // The subpage describes a live connection and has nothing to say once it ends — whether the
    // user ended it from the page or walked out of range.
    Connections {
        target: root.detailNetwork

        function onActiveChanged() {
            if (!root.detailNetwork.active)
                root.detailOpen = false;
        }
    }

    DetailPanel {
        id: panel

        anchors.fill: parent
        title: "Wi-Fi"
        subtitle: "Tap a network to connect"
        scanning: Network.wifiScanning
        switchLabel: "Use Wi-Fi"
        switchChecked: Network.wifiEnabled

        onSwitchToggled: Network.toggleWifi()
        onDone: root.closePanel()

        footerLeading: RippleButton {
            implicitHeight: 40
            implicitWidth: 120
            padding: 0
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colPrimary

            onClicked: Network.openConnectionEditor()

            contentItem: Text {
                text: "Advanced"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.bold: true
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        ListView {
            id: networkList

            anchors.fill: parent
            clip: true
            spacing: 0

            model: ScriptModel {
                values: Network.visibleWifiNetworks(root.sortedNetworks, root.collapsedCount, root.showAll)
            }

            delegate: WiFiNetworkItem {
                required property WifiAccessPoint modelData

                network: modelData
                // Not anchors to `parent`: a vertical ListView's contentItem carries no width of
                // its own, so an anchored row collapses to nothing.
                width: networkList.width

                onOpenDetails: {
                    root.detailNetwork = network;
                    root.detailOpen = true;
                }
            }

            footer: RippleButton {
                width: networkList.width
                implicitHeight: visible ? 48 : 0
                visible: root.sortedNetworks.length > root.collapsedCount
                padding: 0
                buttonRadius: Appearance.rounding.normal
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colPrimary

                onClicked: root.showAll = !root.showAll

                contentItem: Item {
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        text: root.showAll ? "See less" : "See all"
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    CustomIcon {
                        anchors {
                            right: parent.right
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        width: 20
                        height: 20
                        source: "go-down-symbolic"
                        colorize: true
                        color: Appearance.colors.colOnLayer0
                        rotation: root.showAll ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animation.expressiveEffects
                            }
                        }
                    }
                }
            }
        }
    }

    WiFiNetworkDetailPage {
        id: detailPage

        width: root.width
        height: root.height
        x: root.detailOpen ? 0 : root.width
        visible: x < root.width
        network: root.detailNetwork

        onBack: root.detailOpen = false

        Behavior on x {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }
    }
}
