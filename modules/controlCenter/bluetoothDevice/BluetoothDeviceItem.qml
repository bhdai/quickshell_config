import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    horizontalPadding: 20
    verticalPadding: 12
    clip: true
    required property var device
    property bool expanded: false
    pointingHandCursor: !expanded
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + verticalPadding * 2
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.38, 1.21, 0.22, 1.00, 1, 1]
        }
    }
    colBackground: Colors.background
    colBackgroundHover: Colors.surfaceHover
    colRipple: Colors.primary
    buttonRadius: 0

    onClicked: expanded = !expanded
    altAction: () => expanded = !expanded

    component ActionButton: RippleButton {
        id: actionButton

        implicitHeight: 36
        implicitWidth: 80
        padding: 14
        buttonRadius: 9999
        property color colText: actionButton.enabled ? Colors.text : Colors.background

        contentItem: Text {
            anchors.fill: parent
            anchors.leftMargin: actionButton.padding
            anchors.rightMargin: actionButton.padding
            text: actionButton.buttonText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 12
            color: actionButton.colText
        }
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            // Name
            spacing: 10

            CustomIcon {
                property string symbol: {
                    const name = root.device?.icon;
                    if (name.includes("headset"))
                        return "audio-headset-symbolic";
                    if (name.includes("headphones"))
                        return "audio-headphones-symbolic";
                    if (name.includes("audio"))
                        return "audio-speakers-symbolic";
                    if (name.includes("phone"))
                        return "phone-apple-iphone-symbolic";
                    if (name.includes("mouse"))
                        return "input-mouse-symbolic";
                    if (name.includes("keyboard"))
                        return "input-keyboard-symbolic";
                    return "bluetooth-active-symbolic";
                }

                source: symbol
                width: 20
                height: 20
                colorize: true
                color: Colors.text
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    color: Colors.text
                    elide: Text.ElideRight
                    text: root.device?.name || "Unknown device"
                }
                Text {
                    visible: (root.device?.connected || root.device?.paired) ?? false
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    color: Colors.subtext1
                    elide: Text.ElideRight
                    text: {
                        if (!root.device?.paired)
                            return "";
                        let statusText = root.device?.connected ? "Connected" : "Paired";
                        if (!root.device?.batteryAvailable)
                            return statusText;
                        statusText += ` • ${Math.round(root.device?.battery * 100)}%`;
                        return statusText;
                    }
                }
            }

            CustomIcon {
                source: "go-down-symbolic"
                width: 15
                height: 15
                colorize: true
                color: Colors.text
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
                    }
                }
            }
        }

        RowLayout {
            visible: root.expanded
            Layout.topMargin: 8
            Item {
                Layout.fillWidth: true
            }
            ActionButton {
                buttonText: root.device?.connected ? "Disconnect" : "Connect"
                colBackground: Colors.primary
                colBackgroundHover: ColorUtils.transparentize(colBackground, 0.2)
                colText: Colors.m3onPrimary

                onClicked: {
                    if (root.device?.connected) {
                        root.device.disconnect();
                    } else {
                        // If not paired, pair first then connect
                        // Also set trusted=true so the device is remembered for future connections
                        if (!root.device?.paired) {
                            root.device.pair();
                        }
                        root.device.trusted = true;
                        root.device.connect();
                    }
                }
            }
            ActionButton {
                // Show Forget button if device is paired, bonded, or trusted
                visible: (root.device?.paired || root.device?.bonded || root.device?.trusted) ?? false
                colBackground: Colors.colError
                colBackgroundHover: ColorUtils.transparentize(colBackground, 0.2)
                colRipple: Colors.onError
                colText: Colors.onError

                buttonText: "Forget"
                onClicked: {
                    root.device?.forget();
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
