import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var notif

    width: 400
    implicitHeight: mainLayout.implicitHeight + 10 // 5px padding on top/bottom
    radius: 15
    color: Colors.background

    // pause timeout on hover
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        property bool isInside: containsMouse
        onIsInsideChanged: {
            if (root.notif) {
                root.notif.setPaused(isInside);
            }
        }

        onClicked: {
            // close on click (always, whether there are actions or not)
            Notifications.hideNotificationPopup(root.notif.notificationId);
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 5
        spacing: 0

        // header Section
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.bottomMargin: 4

            Item {
                id: iconContainer
                implicitWidth: 20
                implicitHeight: 20

                // Show app icon if available
                Loader {
                    id: appIconLoader
                    anchors.fill: parent
                    active: root.notif && root.notif.appIcon
                    sourceComponent: IconImage {
                        source: root.notif ? Quickshell.iconPath(root.notif.appIcon, true) : ""
                        implicitSize: 20
                        visible: source !== ""
                    }
                }

                // Show Material Symbol fallback if no app icon
                Loader {
                    id: materialSymbolLoader
                    anchors.fill: parent
                    active: root.notif && !root.notif.appIcon
                    sourceComponent: MaterialSymbol {
                        text: "lightbulb"
                        fill: 1
                        iconSize: 20
                        color: Colors.accent // Adjust as needed
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                text: root.notif ? root.notif.appName : ""
                Layout.leftMargin: 8
                opacity: 0.8
                color: Colors.text
                font.pointSize: 10
            }

            Item {
                Layout.fillWidth: true
            } // spacer

            Text {
                id: timeDisplay
                opacity: 0.7
                color: Colors.text
                font.pointSize: 9
                Component.onCompleted: {
                    timeDisplay.text = Time.hoursMinutes;
                }
            }

            Item {
                id: closeButtonContainer
                property real iconSize: 15
                implicitWidth: iconSize
                implicitHeight: iconSize
                CustomIcon {
                    id: closeIcon
                    source: "window-close-symbolic"
                    anchors.centerIn: parent
                    width: closeButtonContainer.iconSize
                    height: closeButtonContainer.iconSize
                    colorize: true
                    color: Colors.powerButton
                }
            }
        }

        // separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.text
            opacity: 0.5
        }

        // time out progress bar
        Rectangle {
            id: progressBar
            width: parent.width * (root.notif.timeLeft > 0 && root.notif.timeout > 0 ? notif.timeLeft / notif.timeout : 0)
            Layout.bottomMargin: 5
            height: 3
            radius: 3
            color: Colors.accent

            Behavior on width {
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.Linear
                }
            }
        }

        // content section
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            Layout.leftMargin: 5
            Layout.rightMargin: 5
            spacing: 10

            ClippingWrapperRectangle {
                radius: 8
                antialiasing: true
                visible: root.notif && root.notif.image !== ""
                Item {
                    id: notificationImageContainer
                    implicitWidth: 86
                    implicitHeight: 86
                    anchors.centerIn: parent

                    Image {
                        id: notificationImage
                        anchors.fill: parent
                        source: {
                            if (root.notif && root.notif.image) {
                                let imagePath = root.notif.image;

                                // convert "image://icon/home/user/..." → "file:///home/user/..."
                                if (imagePath.startsWith("image://icon/")) {
                                    const stripped = imagePath.replace("image://icon/", "");
                                    if (stripped.startsWith("~/"))
                                        return "file://" + stripped.replace("~", Quickshell.homePath);
                                    if (!stripped.startsWith("/"))
                                        return "file:///" + stripped;
                                    return "file://" + stripped;
                                }

                                // handle normal "~/" paths
                                if (imagePath.startsWith("~/"))
                                    return "file://" + imagePath.replace("~", Quickshell.homePath);

                                // handle already-valid file URLs
                                if (imagePath.startsWith("file://"))
                                    return imagePath;

                                // default case
                                return imagePath;
                            }
                            return "";
                        }
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        asynchronous: true
                        visible: source !== ""

                        // Component.onCompleted: {
                        //     console.log("Notification image source:", notificationImage.source);
                        // }
                    }
                }
            }

            // right column: summary & body
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: root.notif ? root.notif.summary : ""
                    font.bold: true
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    color: Colors.text
                    Layout.fillWidth: true
                }

                Text {
                    text: root.notif ? root.notif.body : ""
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText // to handle markup if any
                    color: Colors.text
                    Layout.fillWidth: true
                }
            }
        }

        // actions
        RowLayout {
            id: actionsRow
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 5
            Layout.rightMargin: 5
            spacing: 6
            visible: root.notif && root.notif.actions && root.notif.actions.length > 0

            Repeater {
                model: root.notif ? root.notif.actions : []
                delegate: Button {
                    text: modelData.text
                    onClicked: Notifications.attemptInvokeAction(root.notif.notificationId, modelData.identifier)
                }
            }
        }

        // inline reply
        Loader {
            id: inlineReplyLoader
            Layout.fillWidth: true
            Layout.topMargin: 4
            active: false
            sourceComponent: RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 5
                Layout.rightMargin: 5
                spacing: 6
                TextField {
                    id: replyField
                    Layout.fillWidth: true
                    placeholderText: "Reply…"
                    selectByMouse: true
                }
                Button {
                    text: "Send"
                    enabled: replyField.text.length > 0
                    onClicked: {
                        root.notif.notification.sendInlineReply(replyField.text);
                        if (!root.notif.notification.resident) {
                            Notifications.discardNotification(root.notif.notificationId);
                        }
                    }
                }
            }
        }
    }
}
