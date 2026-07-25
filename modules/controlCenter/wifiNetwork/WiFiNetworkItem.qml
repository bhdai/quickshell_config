import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * One network in the Wi-Fi panel's list. The connected network wears the accent pill and opens
 * its detail subpage from the gear; every other row connects on tap and grows an inline
 * password field when NetworkManager asks for secrets.
 */
SplitTargetRow {
    id: root

    required property WifiAccessPoint network

    readonly property bool connected: root.network?.active ?? false
    readonly property bool askingPassword: root.network?.askingPassword ?? false
    readonly property bool connecting: Network.wifiConnectTarget === root.network
    readonly property color colForeground: root.connected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0

    signal openDetails

    // Only the connected network has a detail page: every row on it describes a live connection.
    trailingVisible: root.connected
    colBackground: root.connected ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: root.connected ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1Hover
    colDivider: root.connected ? Appearance.colors.colOnPrimary : Appearance.colors.colOutlineVariant
    colTrailing: root.colForeground
    trailingPadding: 4

    // The row owns its height rather than reading the prompt's geometry back through a layout,
    // so the expand animates without the prompt's size chasing the row's.
    implicitHeight: 64 + (root.askingPassword ? passwordPrompt.implicitHeight + 12 : 0)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 400
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial
        }
    }

    onBodyClicked: {
        if (!root.network || root.connected)
            return;
        Network.connectToWifiNetwork(root.network);
    }

    onTrailingClicked: root.openDetails()

    Item {
        anchors.fill: parent
        clip: true

        RowLayout {
            id: networkRow

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 16
                rightMargin: 16
            }
            height: 64
            spacing: 12

            CustomIcon {
                width: 24
                height: 24
                source: Network.networkSymbol(root.network?.strength ?? 0)
                colorize: true
                color: root.colForeground
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.network?.ssid ?? "Unknown"
                    color: root.colForeground
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "Connected"
                    visible: root.connected
                    color: root.colForeground
                    opacity: 0.8
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            CustomIcon {
                width: 20
                height: 20
                visible: !root.connected && (root.connecting || (root.network?.isSecure ?? false))
                source: root.connecting ? "content-loading-symbolic" : "channel-secure-symbolic"
                colorize: true
                color: root.colForeground
            }
        }

        ColumnLayout {
            id: passwordPrompt

            anchors {
                left: parent.left
                right: parent.right
                top: networkRow.bottom
                leftMargin: 16
                rightMargin: 16
            }
            visible: root.askingPassword
            spacing: 4

            MaterialTextField {
                id: passwordField

                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onAccepted: Network.changePassword(root.network, passwordField.text)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Item {
                    Layout.fillWidth: true
                }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 90
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colPrimary

                    contentItem: Text {
                        text: "Cancel"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                    }

                    onClicked: {
                        if (root.network)
                            root.network.askingPassword = false;
                    }
                }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 90
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colPrimary

                    contentItem: Text {
                        text: "Connect"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.bold: true
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                    onClicked: Network.changePassword(root.network, passwordField.text)
                }
            }
        }
    }
}
